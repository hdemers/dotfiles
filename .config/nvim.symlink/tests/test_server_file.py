"""Real-Neovim startup and filesystem tests for the CWD server record.

Run with: uv run --with pynvim python3 .config/nvim.symlink/tests/test_server_file.py
"""

from __future__ import annotations

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest

import pynvim


CONFIG_DIR = Path(__file__).resolve().parents[1]


class StartedNeovim:
  def __init__(
    self, project: Path, root: Path, name: str, visible: bool, init_hook: str = ''
  ) -> None:
    self.socket = root / f'{name}.sock'
    self.nvim: pynvim.Nvim | None = None
    init = root / f'{name}.lua'
    init.write_text(
      "vim.opt.rtp:append(" + repr(str(CONFIG_DIR)) + ")\n" + init_hook,
      encoding='utf-8',
    )
    environment = os.environ.copy()
    for directory in ('config', 'data', 'state', 'cache'):
      environment[f'XDG_{directory.upper()}_HOME'] = str(root / directory)
    arguments = [
      'nvim',
      '--embed',
      '--listen',
      str(self.socket),
      '-u',
      str(init),
      '-i',
      'NONE',
    ]
    if not visible:
      arguments.append('--headless')
    self.process = subprocess.Popen(
      arguments,
      cwd=project,
      env=environment,
      stdin=subprocess.PIPE,
      stdout=subprocess.DEVNULL,
      stderr=subprocess.DEVNULL,
    )
    try:
      self.nvim = self._connect()
      if visible:
        self.nvim.ui_attach(240, 60, rgb=True)
      self._wait_for_vim_enter()
    except BaseException:
      self.close()
      raise

  def _connect(self) -> pynvim.Nvim:
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
      if self.process.poll() is not None:
        raise RuntimeError('Neovim exited before accepting RPC connections')
      try:
        return pynvim.attach('socket', path=str(self.socket))
      except OSError:
        time.sleep(0.05)
    raise TimeoutError('Neovim did not accept an RPC connection')

  def _wait_for_vim_enter(self) -> None:
    deadline = time.monotonic() + 5
    while time.monotonic() < deadline:
      if self.process.poll() is not None:
        raise RuntimeError('Neovim exited before VimEnter')
      try:
        if self.nvim is not None and self.nvim.eval('v:vim_did_enter'):
          return
      except (EOFError, OSError):
        pass
      time.sleep(0.05)
    raise TimeoutError('VimEnter did not complete')

  def close(self) -> None:
    try:
      if self.process.poll() is None and self.nvim is not None:
        try:
          self.nvim.command('qa!')
        except (pynvim.NvimError, EOFError, OSError):
          pass
      try:
        self.process.wait(timeout=5)
      except subprocess.TimeoutExpired:
        self.process.kill()
        self.process.wait(timeout=5)
    finally:
      if self.process.stdin is not None:
        self.process.stdin.close()
      if self.nvim is not None:
        self.nvim.close()


class ServerFileTests(unittest.TestCase):
  def setUp(self) -> None:
    self.root = Path(tempfile.mkdtemp(prefix='nvim-server-file-'))
    self.project = self.root / 'project'
    self.project.mkdir()
    self.instances: list[StartedNeovim] = []

  def tearDown(self) -> None:
    for instance in reversed(self.instances):
      instance.close()
    self.project.chmod(0o700)
    shutil.rmtree(self.root, ignore_errors=True)

  def start(
    self, name: str, visible: bool = True, init_hook: str = ''
  ) -> StartedNeovim:
    instance = StartedNeovim(self.project, self.root, name, visible, init_hook)
    self.instances.append(instance)
    return instance

  def test_visible_startup_publishes_its_server_in_its_current_working_directory(self) -> None:
    nvim = self.start('visible')

    self.assertEqual(
      (self.project / '.nvim.server').read_text(encoding='utf-8'), f'{nvim.socket}\n'
    )

  def test_headless_startup_preserves_an_existing_visible_server_record(self) -> None:
    server_file = self.project / '.nvim.server'
    server_file.write_text('visible-server\n', encoding='utf-8')

    self.start('headless', visible=False)

    self.assertEqual(server_file.read_text(encoding='utf-8'), 'visible-server\n')

  def test_exit_removes_the_record_owned_by_that_visible_instance(self) -> None:
    nvim = self.start('owner')
    server_file = self.project / '.nvim.server'
    self.assertTrue(server_file.exists())

    nvim.close()
    self.instances.remove(nvim)

    self.assertFalse(server_file.exists())

  def test_older_instance_exit_preserves_the_newer_instance_record(self) -> None:
    older = self.start('older')
    newer = self.start('newer')
    server_file = self.project / '.nvim.server'

    older.close()
    self.instances.remove(older)

    self.assertEqual(server_file.read_text(encoding='utf-8'), f'{newer.socket}\n')

  def test_startup_replaces_a_server_file_symlink_without_changing_its_target(self) -> None:
    target = self.root / 'unrelated'
    target.write_text('do not change\n', encoding='utf-8')
    server_file = self.project / '.nvim.server'
    server_file.symlink_to(target)

    self.start('symlink')

    self.assertFalse(server_file.is_symlink())
    self.assertEqual(target.read_text(encoding='utf-8'), 'do not change\n')

  def test_exit_cleans_the_original_record_after_a_directory_change(self) -> None:
    nvim = self.start('cwd-change')
    original_file = self.project / '.nvim.server'
    later_directory = self.root / 'later'
    later_directory.mkdir()

    nvim.nvim.command(f'cd {later_directory}')
    nvim.close()
    self.instances.remove(nvim)

    self.assertFalse(original_file.exists())
    self.assertFalse((later_directory / '.nvim.server').exists())

  def test_cleanup_race_preserves_a_replacement_before_claim_or_unlink(self) -> None:
    first_replacement = self.root / 'replacement-before-claim'
    hook = f"""
      local server_file = {str(self.project / '.nvim.server')!r}
      local replacement = {str(first_replacement)!r}
      local original_rename = vim.uv.fs_rename
      local original_unlink = vim.uv.fs_unlink
      local replaced = false
      vim.fn.writefile({{ 'replacement-before-claim' }}, replacement)
      local function replace_record()
        if not replaced then
          replaced = true
          original_rename(replacement, server_file)
        end
      end
      vim.uv.fs_rename = function(old_path, new_path)
        if old_path == server_file then
          replace_record()
        end
        return original_rename(old_path, new_path)
      end
      vim.uv.fs_unlink = function(path)
        if path == server_file then
          replace_record()
        end
        return original_unlink(path)
      end
    """
    nvim = self.start('cleanup-race', init_hook=hook)

    nvim.close()
    self.instances.remove(nvim)

    self.assertEqual(
      (self.project / '.nvim.server').read_text(encoding='utf-8'),
      'replacement-before-claim\n',
    )

  def test_cleanup_race_restores_a_foreign_symlink_without_touching_its_target(self) -> None:
    target = self.root / 'unrelated-target'
    target.write_text('do not change\n', encoding='utf-8')
    replacement = self.root / 'foreign-symlink'
    replacement.symlink_to(target)
    hook = f"""
      local server_file = {str(self.project / '.nvim.server')!r}
      local replacement = {str(replacement)!r}
      local original_rename = vim.uv.fs_rename
      local replaced = false
      vim.uv.fs_rename = function(old_path, new_path)
        if old_path == server_file and not replaced then
          replaced = true
          original_rename(replacement, server_file)
        end
        return original_rename(old_path, new_path)
      end
    """
    nvim = self.start('symlink-race', init_hook=hook)

    nvim.close()
    self.instances.remove(nvim)

    server_file = self.project / '.nvim.server'
    self.assertTrue(server_file.is_symlink())
    self.assertEqual(server_file.readlink(), target)
    self.assertEqual(target.read_text(encoding='utf-8'), 'do not change\n')

  def test_cleanup_race_preserves_a_newer_record_before_foreign_restore(self) -> None:
    first_replacement = self.root / 'replacement-before-restore'
    second_replacement = self.root / 'replacement-during-restore'
    hook = f"""
      local server_file = {str(self.project / '.nvim.server')!r}
      local first_replacement = {str(first_replacement)!r}
      local second_replacement = {str(second_replacement)!r}
      local original_link = vim.uv.fs_link
      local original_rename = vim.uv.fs_rename
      local replaced = false
      local replaced_again = false
      vim.fn.writefile({{ 'replacement-before-restore' }}, first_replacement)
      vim.fn.writefile({{ 'replacement-during-restore' }}, second_replacement)
      vim.uv.fs_rename = function(old_path, new_path)
        if old_path == server_file and not replaced then
          replaced = true
          original_rename(first_replacement, server_file)
        end
        return original_rename(old_path, new_path)
      end
      vim.uv.fs_link = function(old_path, new_path)
        if new_path == server_file and not replaced_again then
          replaced_again = true
          original_rename(second_replacement, server_file)
        end
        return original_link(old_path, new_path)
      end
    """
    nvim = self.start('restore-race', init_hook=hook)

    nvim.close()
    self.instances.remove(nvim)

    self.assertEqual(
      (self.project / '.nvim.server').read_text(encoding='utf-8'),
      'replacement-during-restore\n',
    )

  def test_startup_write_failure_leaves_no_temporary_record_and_keeps_neovim_running(self) -> None:
    (self.project / '.nvim.server').mkdir()

    nvim = self.start('publish-failure')

    self.assertEqual(nvim.nvim.eval('v:vim_did_enter'), 1)
    self.assertTrue((self.project / '.nvim.server').is_dir())
    self.assertEqual(list(self.project.glob(',.nvim.server.*')), [])


if __name__ == '__main__':
  unittest.main()
