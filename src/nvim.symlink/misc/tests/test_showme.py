"""Real-Neovim UI behavior tests for misc.ShowMe/ClearShowMe.

Run with: uv run --with pynvim python3 src/nvim.symlink/misc/tests/test_showme.py
"""

from __future__ import annotations

import json
import os
import signal
import tempfile
import unittest
from pathlib import Path

import pynvim


MISC_ROOT = Path(__file__).resolve().parents[1]


class AttachedNvim:
  def __init__(self, state_home: str | None = None) -> None:
    # Never touch the user's real state: stdpath('state') follows XDG_STATE_HOME.
    self._own_state = None
    if state_home is None:
      self._own_state = tempfile.TemporaryDirectory()
      state_home = self._own_state.name
    self.state_home = state_home
    self.nvim = pynvim.attach(
      'child',
      argv=[
        'env', f'XDG_STATE_HOME={state_home}',
        'nvim', '--embed', '--clean', '-u', 'NONE', '-i', 'NONE',
      ],
    )
    self.width = 80
    self.height = 20
    self.rows = [[' '] * self.width for _ in range(self.height)]
    self.attributes = [[0] * self.width for _ in range(self.height)]
    self.highlight_attributes: dict[int, dict[str, int]] = {}
    self.events: list[object] = []
    self.nvim.request(
      'nvim_ui_attach', self.width, self.height, {'ext_linegrid': True, 'rgb': True}
    )
    self.nvim.exec_lua(
      """
      vim.opt.rtp:prepend(...)
      vim.o.laststatus = 0
      vim.o.ruler = false
      vim.o.number = false
      vim.o.relativenumber = false
      vim.o.signcolumn = 'no'
      """,
      [str(MISC_ROOT)],
    )

  def _redraw(self, redraw: list[object]) -> None:
    for event in redraw:
      if event[0] == 'hl_attr_define':
        for attribute, rgb, _, _ in event[1:]:
          self.highlight_attributes[attribute] = rgb
      elif event[0] == 'grid_resize':
        _, width, height = event[1]
        self.width, self.height = width, height
        self.rows = [[' '] * width for _ in range(height)]
        self.attributes = [[0] * width for _ in range(height)]
      elif event[0] == 'grid_line':
        for grid, row, column, cells, _ in event[1:]:
          if grid != 1:
            continue
          col = column
          attribute = self.attributes[row][column - 1] if column else 0
          for cell in cells:
            text = cell[0]
            attribute = cell[1] if len(cell) > 1 else attribute
            repeat = cell[2] if len(cell) > 2 else 1
            for _ in range(repeat):
              if row < self.height and col < self.width:
                self.rows[row][col] = text
                self.attributes[row][col] = attribute
              col += 1

  def flush(self) -> None:
    self.events.clear()
    self.nvim.exec_lua(
      "vim.schedule(function() vim.rpcnotify(0, 'showme-test-redraw-complete') end)"
    )

    def request(_, __):
      return None

    def notification(name, args):
      if name == 'redraw':
        self.events.extend(args)
        self._redraw(args)
      elif name == 'showme-test-redraw-complete':
        self.nvim.stop_loop()

    self.nvim.run_loop(request, notification)

  def text(self) -> str:
    return '\n'.join(''.join(row) for row in self.rows)

  def row_for(self, text: str) -> int:
    return next(index for index, row in enumerate(self.rows) if text in ''.join(row))

  def attributes_for(self, text: str) -> dict[str, int]:
    row = self.row_for(text)
    column = ''.join(self.rows[row]).index(text)
    return self.highlight_attributes[self.attributes[row][column]]

  def row_has_background(self, row: int, background: int) -> bool:
    return any(
      self.highlight_attributes.get(attribute, {}).get('background') == background
      for attribute in self.attributes[row]
    )

  def left_text_width_has_background(self, row: int, background: int) -> bool:
    separator = ''.join(self.rows[row]).index('│')
    return all(
      self.highlight_attributes.get(attribute, {}).get('background') == background
      for attribute in self.attributes[row][:separator]
    )

  def window_text_area_bounds(self, window: int) -> tuple[int, int, int]:
    bounds = self.nvim.exec_lua(
      """
      local window = (...)[1]
      local position = vim.api.nvim_win_get_position(window)
      return {
        window_left = position[2],
        text_left = position[2] + vim.fn.getwininfo(window)[1].textoff,
        right = position[2] + vim.api.nvim_win_get_width(window),
      }
      """,
      [window],
    )
    return bounds['window_left'], bounds['text_left'], bounds['right']

  def text_area_bounds(self, window: int) -> tuple[int, int]:
    _, left, right = self.window_text_area_bounds(window)
    return left, right

  def row_for_window_text(self, window: int, text: str) -> int:
    left, right = self.text_area_bounds(window)
    return next(
      row for row, cells in enumerate(self.rows) if text in ''.join(cells[left:right])
    )

  def text_area_has_background(self, row: int, window: int, background: int) -> bool:
    left, right = self.text_area_bounds(window)
    return all(
      self.highlight_attributes.get(attribute, {}).get('background') == background
      for attribute in self.attributes[row][left:right]
    )

  def kill(self) -> None:
    """Simulate a crash: SIGKILL, so no exit handler runs."""
    pid = self.nvim.eval('getpid()')
    os.kill(pid, signal.SIGKILL)
    self.killed = True

  def close(self) -> None:
    if getattr(self, 'killed', False):
      try:
        self.nvim.close()
      except Exception:
        pass
    else:
      try:
        self.nvim.command('qa!')
      except EOFError:
        pass
      self.nvim.close()
    if self._own_state is not None:
      self._own_state.cleanup()


class ShowMeBehaviorTest(unittest.TestCase):
  def setUp(self) -> None:
    self.nvim = AttachedNvim()
    self.addCleanup(self.nvim.close)

  def showme(
    self, filename: Path, message: str, side: str, line_range: list[int] | None = None
  ) -> None:
    self.nvim.nvim.exec_lua(
      "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
      [str(filename), line_range or [1, 1], message, side],
    )

  def clear_showme(self, side: str | None = None) -> None:
    if side is None:
      self.nvim.nvim.exec_lua("return require('misc').ClearShowMe()")
    else:
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ClearShowMe(args[1])", [side]
      )

  def test_showme_from_single_nofile_window_uses_a_separate_two_pane_tab(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('presented source\n')
      original_tab = self.nvim.nvim.request('nvim_get_current_tabpage')
      original_tab_number = self.nvim.nvim.eval('tabpagenr()')
      original_window = self.nvim.nvim.request('nvim_get_current_win')
      original_buffer = self.nvim.nvim.request('nvim_win_get_buf', original_window)
      self.nvim.nvim.exec_lua("vim.bo.buftype = 'nofile'")

      self.showme(source, 'separate presentation', 'left')
      self.nvim.flush()

      presentation = self.nvim.nvim.request('nvim_get_current_tabpage')
      self.assertNotEqual(original_tab, presentation)
      self.assertEqual(2, len(self.nvim.nvim.request('nvim_tabpage_list_wins', presentation)))
      self.assertEqual(
        original_tab_number,
        self.nvim.nvim.exec_lua("return vim.api.nvim_tabpage_get_number(vim.api.nvim_list_tabpages()[1])"),
      )
      self.assertEqual(original_buffer, self.nvim.nvim.request('nvim_win_get_buf', original_window))
      self.assertIn('presented source', self.nvim.text())
      self.assertIn('separate presentation', self.nvim.text())

  def test_standalone_quit_reuses_its_tab_and_restores_origin_view(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text(''.join(f'line {index}\n' for index in range(1, 20)))
      self.nvim.nvim.command(f'edit {source}')
      self.nvim.nvim.command('normal! 8Gzt')
      origin = self.nvim.nvim.request('nvim_get_current_win')
      cursor = self.nvim.nvim.request('nvim_win_get_cursor', origin)

      self.showme(source, 'left note', 'left')
      self.showme(source, 'right note', 'right')
      self.assertEqual(2, len(self.nvim.nvim.request('nvim_list_tabpages')))
      self.nvim.nvim.input('\\tq')
      self.nvim.flush()

      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))
      self.assertEqual(origin, self.nvim.nvim.request('nvim_get_current_win'))
      self.assertEqual(cursor, self.nvim.nvim.request('nvim_win_get_cursor', origin))
      self.assertNotIn('left note', self.nvim.text())

  def test_tour_navigation_reveals_presentation_and_final_next_keeps_outside_focus(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('first\nsecond\n')
      scenes = [
        {'left': {'filename': str(source), 'range': [1, 1], 'message': 'first scene'}},
        {'left': {'filename': str(source), 'range': [2, 2], 'message': 'second scene'}},
      ]
      self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
      presentation = self.nvim.nvim.request('nvim_get_current_tabpage')
      self.nvim.nvim.command('tabnew')
      outside = self.nvim.nvim.request('nvim_get_current_tabpage')

      self.nvim.nvim.exec_lua("require('misc').TourNext()")
      self.assertEqual(presentation, self.nvim.nvim.request('nvim_get_current_tabpage'))
      self.nvim.nvim.command('tabnext 3')
      self.assertEqual(outside, self.nvim.nvim.request('nvim_get_current_tabpage'))
      self.nvim.nvim.exec_lua("require('misc').TourNext()")

      self.assertEqual(outside, self.nvim.nvim.request('nvim_get_current_tabpage'))
      self.assertEqual(2, len(self.nvim.nvim.request('nvim_list_tabpages')))

  def test_tab_leave_restores_shared_buffer_mapping_and_reenter_reinstalls_navigation(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('first\nsecond\n')
      self.nvim.nvim.command(f'edit {source}')
      self.nvim.nvim.exec_lua(
        "vim.keymap.set('n', ']t', function() vim.g.original_mapping = true end, { buffer = true })"
      )
      scenes = [
        {'left': {'filename': str(source), 'range': [1, 1], 'message': 'first scene'}},
        {'left': {'filename': str(source), 'range': [2, 2], 'message': 'second scene'}},
      ]
      self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
      self.nvim.nvim.command('tabprevious')
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertTrue(self.nvim.nvim.eval('get(g:, "original_mapping", 0)'))

      self.nvim.nvim.command('tabnext')
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertIn('second scene', self.nvim.text())

  def test_manual_owned_tab_close_clears_state_for_a_fresh_presentation(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('presented\n')
      self.showme(source, 'first presentation', 'left')
      self.nvim.nvim.command('tabclose')
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))

      self.showme(source, 'fresh presentation', 'right')
      self.nvim.flush()
      self.assertEqual(2, len(self.nvim.nvim.request('nvim_list_tabpages')))
      self.assertIn('fresh presentation', self.nvim.text())

  def test_replaced_presentation_buffers_receive_only_current_mappings(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      first = Path(directory) / 'first.lua'
      second = Path(directory) / 'second.lua'
      third = Path(directory) / 'third.lua'
      first.write_text('first\n')
      second.write_text('second\n')
      third.write_text('third\n')

      self.showme(first, 'first note', 'left')
      first_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(first)])
      self.showme(second, 'second note', 'left')
      second_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(second)])
      self.assertEqual(
        0,
        self.nvim.nvim.exec_lua(
          "return vim.api.nvim_buf_call((...)[1], function() return vim.fn.maparg(vim.keycode('\\\\tq'), 'n', false, true).buffer or 0 end)",
          [first_buffer],
        ),
      )
      self.nvim.nvim.input('\\tq')
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))

      scenes = [
        {'left': {'filename': str(first), 'range': [1, 1], 'message': 'tour first'}},
        {'left': {'filename': str(second), 'range': [1, 1], 'message': 'tour second'}},
        {'left': {'filename': str(third), 'range': [1, 1], 'message': 'tour third'}},
      ]
      self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertIn('tour second', self.nvim.text())
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertIn('tour third', self.nvim.text())
      self.assertEqual(
        0,
        self.nvim.nvim.exec_lua(
          "return vim.api.nvim_buf_call((...)[1], function() return vim.fn.maparg(']t', 'n', false, true).buffer or 0 end)",
          [second_buffer],
        ),
      )

  def test_invalid_owned_layout_or_next_scene_from_another_tab_keeps_focus(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('first\nsecond\n')
      scenes = [
        {'left': {'filename': str(source), 'range': [1, 1], 'message': 'first'}},
        {'left': {'filename': str(source), 'range': [2, 2], 'message': 'second'}},
      ]
      self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
      presentation = self.nvim.nvim.request('nvim_get_current_tabpage')
      self.nvim.nvim.command('tabnew')
      outside = self.nvim.nvim.request('nvim_get_current_tabpage')
      source_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
      self.nvim.nvim.request('nvim_buf_set_lines', source_buffer, 1, -1, False, [])

      with self.assertRaisesRegex(pynvim.NvimError, 'beyond the end'):
        self.nvim.nvim.exec_lua("require('misc').TourNext()")
      self.assertEqual(outside, self.nvim.nvim.request('nvim_get_current_tabpage'))

      self.nvim.nvim.request('nvim_buf_set_lines', source_buffer, 1, 1, False, ['second'])
      self.nvim.nvim.request('nvim_set_current_tabpage', presentation)
      self.nvim.nvim.command('only')
      self.nvim.nvim.request('nvim_set_current_tabpage', outside)
      with self.assertRaisesRegex(pynvim.NvimError, 'side-by-side'):
        self.showme(source, 'must not steal focus', 'left')
      self.assertEqual(outside, self.nvim.nvim.request('nvim_get_current_tabpage'))

  def test_native_forced_tab_close_preserves_destructive_presented_buffers(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      for bufhidden in ('wipe', 'delete', 'unload'):
        with self.subTest(bufhidden=bufhidden):
          source = Path(directory) / f'{bufhidden}.lua'
          source.write_text('on disk\n')
          self.showme(source, bufhidden, 'left')
          buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
          self.nvim.nvim.request(
            'nvim_buf_set_lines', buffer, 0, -1, False, [f'unsaved {bufhidden}']
          )
          self.nvim.nvim.exec_lua("vim.bo[(...)[1]].bufhidden = (...)[2]", [buffer, bufhidden])
          replacement = Path(directory) / f'replacement-{bufhidden}.lua'
          replacement.write_text('replacement on disk\n')
          self.showme(replacement, 'replacement', 'left')
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', buffer))
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_loaded', buffer))
          self.assertEqual(
            [f'unsaved {bufhidden}'],
            self.nvim.nvim.request('nvim_buf_get_lines', buffer, 0, -1, False),
          )
          self.assertEqual(bufhidden, self.nvim.nvim.request('nvim_buf_get_option', buffer, 'bufhidden'))

          replacement_buffer = self.nvim.nvim.exec_lua(
            "return vim.fn.bufnr((...)[1])", [str(replacement)]
          )
          self.nvim.nvim.request(
            'nvim_buf_set_lines', replacement_buffer, 0, -1, False, [f'unsaved replacement {bufhidden}']
          )
          self.nvim.nvim.exec_lua(
            "vim.bo[(...)[1]].bufhidden = (...)[2]", [replacement_buffer, bufhidden]
          )
          self.nvim.nvim.command('tabclose!')
          self.nvim.flush()
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', replacement_buffer))
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_loaded', replacement_buffer))
          self.assertEqual(
            [f'unsaved replacement {bufhidden}'],
            self.nvim.nvim.request('nvim_buf_get_lines', replacement_buffer, 0, -1, False),
          )
          self.assertEqual(
            bufhidden, self.nvim.nvim.request('nvim_buf_get_option', replacement_buffer, 'bufhidden')
          )

  def test_background_native_close_preserves_destructive_buffers_and_cleans_up(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      for bufhidden in ('wipe', 'delete', 'unload'):
        with self.subTest(bufhidden=bufhidden):
          source = Path(directory) / f'background-{bufhidden}.lua'
          source.write_text('on disk\n')
          self.showme(source, 'background presentation', 'left')
          buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
          self.nvim.nvim.request(
            'nvim_buf_set_lines', buffer, 0, -1, False, [f'background unsaved {bufhidden}']
          )
          self.nvim.nvim.exec_lua("vim.bo[(...)[1]].bufhidden = (...)[2]", [buffer, bufhidden])
          owned_number = self.nvim.nvim.eval('tabpagenr()')
          self.nvim.nvim.command('tabprevious')
          caller = self.nvim.nvim.request('nvim_get_current_tabpage')

          self.nvim.nvim.command(f'tabclose! {owned_number}')
          self.assertTrue(
            self.nvim.nvim.exec_lua(
              "local args = ...; return vim.wait(1000, function() return vim.api.nvim_buf_is_valid(args[1]) and vim.bo[args[1]].bufhidden == args[2] end, 10)",
              [buffer, bufhidden],
            )
          )
          self.nvim.flush()

          self.assertEqual(caller, self.nvim.nvim.request('nvim_get_current_tabpage'))
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', buffer))
          self.assertTrue(self.nvim.nvim.request('nvim_buf_is_loaded', buffer))
          self.assertEqual(
            [f'background unsaved {bufhidden}'],
            self.nvim.nvim.request('nvim_buf_get_lines', buffer, 0, -1, False),
          )
          self.assertEqual(bufhidden, self.nvim.nvim.request('nvim_buf_get_option', buffer, 'bufhidden'))
          self.assertEqual(
            0,
            self.nvim.nvim.exec_lua(
              "return vim.api.nvim_buf_call((...)[1], function() return vim.fn.maparg(vim.keycode('\\\\tq'), 'n', false, true).buffer or 0 end)",
              [buffer],
            ),
          )

          self.showme(source, 'fresh after background close', 'left')
          self.assertEqual(2, len(self.nvim.nvim.request('nvim_list_tabpages')))
          self.nvim.nvim.input('\\tq')

  def test_outside_tour_dismissal_restores_destructive_buffer_options(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      for dismiss in ('stop', 'finish'):
        for bufhidden in ('wipe', 'delete', 'unload'):
          with self.subTest(dismiss=dismiss, bufhidden=bufhidden):
            source = Path(directory) / f'{dismiss}-{bufhidden}.lua'
            source.write_text('source\n')
            scenes = [
              {'left': {'filename': str(source), 'range': [1, 1], 'message': 'tour source'}}
            ]
            self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
            buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
            self.nvim.nvim.request(
              'nvim_buf_set_lines', buffer, 0, -1, False, [f'unsaved {dismiss} {bufhidden}']
            )
            self.nvim.nvim.exec_lua("vim.bo[(...)[1]].bufhidden = (...)[2]", [buffer, bufhidden])
            self.nvim.nvim.command('tabprevious')
            caller = self.nvim.nvim.request('nvim_get_current_tabpage')

            if dismiss == 'stop':
              self.nvim.nvim.exec_lua("require('misc').TourStop()")
            else:
              self.nvim.nvim.exec_lua("require('misc').TourNext()")

            self.assertEqual(caller, self.nvim.nvim.request('nvim_get_current_tabpage'))
            self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', buffer))
            self.assertTrue(self.nvim.nvim.request('nvim_buf_is_loaded', buffer))
            self.assertEqual(
              [f'unsaved {dismiss} {bufhidden}'],
              self.nvim.nvim.request('nvim_buf_get_lines', buffer, 0, -1, False),
            )
            self.assertEqual(
              bufhidden, self.nvim.nvim.request('nvim_buf_get_option', buffer, 'bufhidden')
            )

  def test_stale_background_guard_cannot_clear_an_immediate_fresh_presentation(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      old_source = Path(directory) / 'old.lua'
      fresh_source = Path(directory) / 'fresh.lua'
      old_source.write_text('old\n')
      fresh_source.write_text('first\nsecond\n')
      self.showme(old_source, 'old presentation', 'left')
      old_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(old_source)])
      self.nvim.nvim.exec_lua("vim.bo[(...)[1]].bufhidden = 'wipe'", [old_buffer])
      old_tab = self.nvim.nvim.eval('tabpagenr()')
      self.nvim.nvim.command('tabprevious')
      self.nvim.nvim.command(f'tabclose! {old_tab}')

      self.showme(fresh_source, 'fresh standalone', 'left')
      scenes = [
        {'left': {'filename': str(fresh_source), 'range': [1, 1], 'message': 'fresh first'}},
        {'left': {'filename': str(fresh_source), 'range': [2, 2], 'message': 'fresh second'}},
      ]
      self.nvim.nvim.exec_lua("local args = ...; require('misc').Tour(args[1])", [scenes])
      fresh_tab = self.nvim.nvim.request('nvim_get_current_tabpage')
      self.nvim.nvim.input(']t')
      self.assertTrue(
        self.nvim.nvim.exec_lua(
          "vim.g.showme_guard_waited = false; vim.defer_fn(function() vim.g.showme_guard_waited = true end, 600); return vim.wait(1000, function() return vim.g.showme_guard_waited end, 10)"
        )
      )
      self.nvim.flush()

      self.assertEqual(fresh_tab, self.nvim.nvim.request('nvim_get_current_tabpage'))
      self.assertIn('fresh second', self.nvim.text())
      fresh_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(fresh_source)])
      self.assertEqual(
        1,
        self.nvim.nvim.exec_lua(
          "return vim.api.nvim_buf_call((...)[1], function() return vim.fn.maparg(']t', 'n', false, true).buffer or 0 end)",
          [fresh_buffer],
        ),
      )

  def test_manual_showme_resets_a_custom_tour_quit_key_to_default(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('presented\n')
      scenes = [{'left': {'filename': str(source), 'range': [1, 1], 'message': 'tour'}}]
      self.nvim.nvim.exec_lua(
        "local args = ...; require('misc').Tour(args[1], args[2])",
        [scenes, {'stop': 'gQ'}],
      )

      self.showme(source, 'standalone', 'left')
      self.nvim.nvim.input('\\tq')
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))

  def test_clearshowme_resets_a_custom_tour_quit_key_to_default(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('presented\n')
      scenes = [{'left': {'filename': str(source), 'range': [1, 1], 'message': 'tour'}}]
      self.nvim.nvim.exec_lua(
        "local args = ...; require('misc').Tour(args[1], args[2])",
        [scenes, {'stop': 'gQ'}],
      )

      self.clear_showme()
      self.nvim.nvim.input('\\tq')
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))

  def test_quit_preserves_a_modified_presented_wipe_buffer(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('on disk\n')
      self.showme(source, 'annotation', 'left')
      buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
      self.nvim.nvim.request(
        'nvim_buf_set_lines', buffer, 0, -1, False, ['unsaved presentation text']
      )
      self.nvim.nvim.exec_lua("vim.bo[(...)[1]].bufhidden = 'wipe'", [buffer])

      self.nvim.nvim.input('\\tq')
      self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', buffer))
      self.assertTrue(self.nvim.nvim.request('nvim_buf_is_loaded', buffer))
      self.assertEqual(
        ['unsaved presentation text'], self.nvim.nvim.request('nvim_buf_get_lines', buffer, 0, -1, False)
      )

  def test_last_presentation_tab_closes_to_a_fallback_when_origin_is_gone(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'source.lua'
      source.write_text('presented\n')
      self.showme(source, 'presentation', 'left')
      self.nvim.nvim.command('tabprevious')
      self.nvim.nvim.command('tabclose')
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))

      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      self.assertEqual(1, len(self.nvim.nvim.request('nvim_list_tabpages')))
      self.assertTrue(self.nvim.nvim.request('nvim_win_is_valid', self.nvim.nvim.request('nvim_get_current_win')))

  def test_tour_starts_with_a_paired_scene_and_footer(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left source\n')
      right.write_text('right source\n')
      self.nvim.nvim.command('vsplit')

      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])",
        [[
          {
            'left': {'filename': str(left), 'range': [1, 1], 'message': 'left tour note'},
            'right': {'filename': str(right), 'range': [1, 1], 'message': 'right tour note'},
          }
        ]],
      )
      self.nvim.nvim.exec_lua("return require('misc').TourPrev()")
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('left source', rendered)
      self.assertIn('right source', rendered)
      self.assertIn('left tour note', rendered)
      self.assertIn('right tour note', rendered)
      self.assertIn('Step 1/1', rendered)
      self.assertIn('previous', rendered)
      self.assertIn('finish', rendered)
      self.assertIn('quit', rendered)

      self.nvim.nvim.input('\\tq')
      self.nvim.flush()
      self.assertNotIn('left tour note', self.nvim.text())
      self.assertNotIn('right tour note', self.nvim.text())

  def test_tour_next_and_previous_replay_paired_and_omitted_sides(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      scenes = [
        {
          'left': {'filename': str(left), 'range': [1, 1], 'message': 'left first'},
          'right': {'filename': str(right), 'range': [1, 1], 'message': 'right first'},
        },
        {'left': {'filename': str(left), 'range': [2, 2], 'message': 'left second'}},
        {'right': {'filename': str(right), 'range': [2, 2], 'message': 'right third'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('left second', rendered)
      self.assertIn('right one', rendered)
      self.assertNotIn('right first', rendered)
      self.assertIn('Step 2/3', rendered)

      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.nvim.exec_lua("return require('misc').TourPrev()")
      self.nvim.flush()
      rendered = self.nvim.text()
      self.assertIn('left second', rendered)
      self.assertNotIn('right third', rendered)
      self.assertNotIn('right first', rendered)

  def test_tour_keyboard_navigation_finishes_and_restores_mappings(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command(f'edit {left}')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.command(f'edit {right}')
      scenes = [
        {
          'left': {'filename': str(left), 'range': [1, 1], 'message': 'first left'},
          'right': {'filename': str(right), 'range': [1, 1], 'message': 'first right'},
        },
        {
          'left': {'filename': str(left), 'range': [2, 2], 'message': 'second left'},
          'right': {'filename': str(right), 'range': [2, 2], 'message': 'second right'},
        },
      ]
      self.nvim.nvim.exec_lua(
        "vim.keymap.set('n', ']t', function() vim.g.tour_global = (vim.g.tour_global or 0) + 1 end)"
      )
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertIn('second left', self.nvim.text())

      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertNotIn('second left', self.nvim.text())
      self.nvim.nvim.input(']t')
      self.nvim.flush()
      self.assertEqual(1, self.nvim.nvim.eval('g:tour_global'))

      windows = self.nvim.nvim.exec_lua(
        """
        local wins = vim.api.nvim_tabpage_list_wins(0)
        table.sort(wins, function(a, b)
          return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
        end)
        return wins
        """
      )
      self.nvim.nvim.exec_lua(
        """
        local args = ...
        local wins = args[1]
        vim.api.nvim_buf_call(vim.api.nvim_win_get_buf(wins[1]), function()
          vim.keymap.set('n', 'gN', function()
            vim.g.tour_callback = 'restored'
            return ''
          end, { buffer = true, expr = true, silent = true, remap = true })
        end)
        """,
        [windows],
      )
      script = Path(directory) / 'tour_mapping.vim'
      script.write_text(
        "function! s:tour_restore() abort\n"
        "  let g:tour_string = 'restored'\n"
        "endfunction\n"
        "nnoremap <script> <buffer> gP <Cmd>call <SID>tour_restore()<CR>\n"
      )
      self.nvim.nvim.request('nvim_set_current_win', windows[1])
      self.nvim.nvim.command(f'source {script}')
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1], args[2])",
        [scenes, {'next': 'gN', 'prev': 'gP', 'stop': 'gQ'}],
      )
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")
      left_mapping = self.nvim.nvim.exec_lua(
        """
        local args = ...
        return vim.api.nvim_buf_call(vim.api.nvim_win_get_buf(args[1]), function()
          local map = vim.fn.maparg('gN', 'n', false, true)
          return { has_callback = map.callback ~= nil, expr = map.expr, silent = map.silent,
            noremap = map.noremap }
        end)
        """,
        [windows[0]],
      )
      self.assertEqual(
        {'has_callback': True, 'expr': 1, 'silent': 1, 'noremap': 0}, left_mapping
      )
      right_mapping = self.nvim.nvim.exec_lua(
        """
        local args = ...
        return vim.api.nvim_buf_call(vim.api.nvim_win_get_buf(args[1]), function()
          local map = vim.fn.maparg('gP', 'n', false, true)
          return { script = map.script, noremap = map.noremap, sid = map.sid }
        end)
        """,
        [windows[1]],
      )
      self.assertEqual(1, right_mapping['script'])
      self.assertEqual(1, right_mapping['noremap'])
      self.assertGreater(right_mapping['sid'], 0)

      self.nvim.nvim.request('nvim_set_current_win', windows[0])
      self.nvim.nvim.input('gN')
      self.nvim.flush()
      self.assertEqual('restored', self.nvim.nvim.eval('g:tour_callback'))
      self.nvim.nvim.request('nvim_set_current_win', windows[1])
      self.nvim.nvim.input('gP')
      self.nvim.flush()
      self.assertEqual('restored', self.nvim.nvim.eval('g:tour_string'))

  def test_tour_replacement_and_invalid_tour_keep_or_replace_active_scene(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      original = [
        {
          'left': {'filename': str(left), 'range': [1, 1], 'message': 'original first'},
          'right': {'filename': str(right), 'range': [1, 1], 'message': 'original right'},
        },
        {'left': {'filename': str(left), 'range': [2, 2], 'message': 'original second'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [original]
      )
      invalid = [
        {
          'left': {'filename': str(left), 'range': [1, 1], 'message': 'would replace'},
          'right': {'filename': str(right), 'range': [9, 9], 'message': 'invalid second side'},
        }
      ]
      with self.assertRaisesRegex(pynvim.NvimError, 'beyond the end'):
        self.nvim.nvim.exec_lua(
          "local args = ...; return require('misc').Tour(args[1])", [invalid]
        )
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertIn('original second', self.nvim.text())
      self.assertNotIn('would replace', self.nvim.text())

      replacement = [
        {'right': {'filename': str(right), 'range': [2, 2], 'message': 'replacement only'}}
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [replacement]
      )
      self.nvim.flush()
      rendered = self.nvim.text()
      self.assertIn('replacement only', rendered)
      self.assertNotIn('original second', rendered)

  def test_manual_showme_and_clearshowme_stop_a_tour_only_after_valid_input(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      missing = Path(directory) / 'missing.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      scenes = [
        {'left': {'filename': str(left), 'range': [1, 1], 'message': 'tour first'}},
        {'right': {'filename': str(right), 'range': [2, 2], 'message': 'tour second'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      with self.assertRaisesRegex(pynvim.NvimError, 'readable file'):
        self.showme(missing, 'invalid manual showme', 'left')
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertIn('tour second', self.nvim.text())

      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.showme(left, 'manual replacement', 'left')
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertIn('manual replacement', self.nvim.text())
      self.assertNotIn('tour second', self.nvim.text())

      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.clear_showme('left')
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertNotIn('tour first', self.nvim.text())
      self.assertNotIn('tour second', self.nvim.text())

  def test_tour_key_collisions_and_invalid_layout_leave_active_tour_recoverable(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      scenes = [
        {'left': {'filename': str(left), 'range': [1, 1], 'message': 'first scene'}},
        {'right': {'filename': str(right), 'range': [2, 2], 'message': 'second scene'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      with self.assertRaisesRegex(pynvim.NvimError, 'must not collide'):
        self.nvim.nvim.exec_lua(
          "local args = ...; return require('misc').Tour(args[1], args[2])",
          [scenes, {'next': 'x', 'prev': 'x'}],
        )
      self.nvim.flush()
      self.assertIn('first scene', self.nvim.text())
      for alias in ('<Enter>', '<C-M>'):
        with self.subTest(alias=alias), self.assertRaisesRegex(
          pynvim.NvimError, 'must not collide'
        ):
          self.nvim.nvim.exec_lua(
            "local args = ...; return require('misc').Tour(args[1], args[2])",
            [scenes, {'next': '<CR>', 'prev': alias, 'stop': 'q'}],
          )
      self.nvim.flush()
      self.assertIn('first scene', self.nvim.text())

      self.nvim.nvim.command('only')
      with self.assertRaisesRegex(pynvim.NvimError, 'side-by-side'):
        self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")
      self.nvim.flush()
      self.assertNotIn('first scene', self.nvim.text())

  def test_tour_stop_uses_frozen_leader_mapping_lhs(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left source\n')
      right.write_text('right source\n')
      self.nvim.nvim.command('vsplit')
      scenes = [
        {
          'left': {'filename': str(left), 'range': [1, 1], 'message': 'left'},
          'right': {'filename': str(right), 'range': [1, 1], 'message': 'right'},
        }
      ]
      self.nvim.nvim.exec_lua("vim.g.mapleader = '\\\\'")
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.nvim.nvim.exec_lua("vim.g.mapleader = ','")
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")

      windows = self.nvim.nvim.exec_lua(
        """
        local wins = vim.api.nvim_tabpage_list_wins(0)
        table.sort(wins, function(a, b)
          return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
        end)
        return wins
        """
      )
      local_mapping = self.nvim.nvim.exec_lua(
        """
        local args = ...
        return vim.api.nvim_buf_call(vim.api.nvim_win_get_buf(args[1]), function()
          return vim.fn.maparg(vim.keycode('\\\\tq'), 'n', false, true).buffer or 0
        end)
        """,
        [windows[0]],
      )
      self.assertEqual(0, local_mapping)

  def test_tour_uses_existing_unsaved_buffer_content(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two on disk\n')
      right.write_text('right one\n')
      self.nvim.nvim.command('vsplit')
      buffer = self.nvim.nvim.exec_lua(
        "local args = ...; return vim.fn.bufadd(args[1])", [str(left)]
      )
      self.nvim.nvim.exec_lua(
        "local args = ...; vim.fn.bufload(args[1]); vim.api.nvim_buf_set_lines(args[1], 1, 2, false, { args[2] })",
        [buffer, 'left two unsaved'],
      )
      scenes = [
        {'left': {'filename': str(left), 'range': [1, 1], 'message': 'first'}},
        {'left': {'filename': str(left), 'range': [2, 2], 'message': 'second'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('left two unsaved', rendered)
      self.assertNotIn('left two on disk', rendered)

  def test_invalid_queued_scene_leaves_current_scene_unchanged(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      scenes = [
        {'left': {'filename': str(left), 'range': [1, 1], 'message': 'current left'}},
        {
          'left': {'filename': str(left), 'range': [2, 2], 'message': 'queued left'},
          'right': {'filename': str(right), 'range': [2, 2], 'message': 'queued right'},
        },
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      right_buffer = self.nvim.nvim.exec_lua(
        "local args = ...; return vim.fn.bufnr(args[1])", [str(right)]
      )
      self.nvim.nvim.request('nvim_buf_set_lines', right_buffer, 1, -1, False, [])

      with self.assertRaisesRegex(pynvim.NvimError, 'beyond the end'):
        self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertIn('current left', self.nvim.text())
      self.assertNotIn('queued left', self.nvim.text())

      self.nvim.nvim.request(
        'nvim_buf_set_lines', right_buffer, 1, 1, False, ['right two restored']
      )
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()
      self.assertIn('queued left', self.nvim.text())
      self.assertIn('queued right', self.nvim.text())

  def test_tour_resolves_relative_paths_before_the_working_directory_changes(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      root = Path(directory)
      left = root / 'left.lua'
      right = root / 'right.lua'
      other = root / 'other'
      other.mkdir()
      left.write_text('left one\nleft two\n')
      right.write_text('right one\nright two\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua("vim.fn.chdir((...)[1])", [str(root)])
      scenes = [
        {'left': {'filename': 'left.lua', 'range': [1, 1], 'message': 'first'}},
        {'right': {'filename': 'right.lua', 'range': [2, 2], 'message': 'second'}},
      ]
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      self.nvim.nvim.exec_lua("vim.fn.chdir((...)[1])", [str(other)])
      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.flush()

      self.assertIn('right two', self.nvim.text())
      self.assertIn('second', self.nvim.text())

  def test_opens_requested_file_in_left_window_and_renders_message(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'a file with spaces.lua'
      filename.write_text('first requested line\nsecond requested line\n')
      self.nvim.nvim.command('vsplit')

      self.showme(filename, 'This annotation is visible.', 'left')
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('first requested line', rendered)
      self.assertIn('This annotation is visible.', rendered)

  def test_keeps_independent_annotations_when_both_windows_show_one_buffer(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'shared.lua'
      filename.write_text('shared requested line\n')
      self.nvim.nvim.command('vsplit')

      self.showme(filename, 'Left-only annotation.', 'left')
      self.showme(filename, 'Right-only annotation.', 'right')
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('Left-only annotation.', rendered)
      self.assertIn('Right-only annotation.', rendered)
      left_row = next(row for row in self.nvim.rows if 'Left-only annotation.' in ''.join(row))
      right_row = next(row for row in self.nvim.rows if 'Right-only annotation.' in ''.join(row))
      left_separator = ''.join(left_row).index('│')
      right_separator = ''.join(right_row).index('│')
      self.assertLess(''.join(left_row).index('Left-only annotation.'), left_separator)
      self.assertNotIn('Left-only annotation.', ''.join(left_row)[left_separator + 1 :])
      self.assertGreater(''.join(right_row).index('Right-only annotation.'), right_separator)
      self.assertNotIn('Right-only annotation.', ''.join(right_row)[:right_separator])

  def test_clears_only_requested_side(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'shared.lua'
      filename.write_text('shared requested line\n')
      self.nvim.nvim.command('vsplit')

      self.showme(filename, 'Left annotation to clear.', 'left')
      self.showme(filename, 'Right annotation to keep.', 'right')
      self.clear_showme('left')
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertNotIn('Left annotation to clear.', rendered)
      self.assertIn('Right annotation to keep.', rendered)

      self.clear_showme()
      self.nvim.flush()
      self.assertNotIn('Right annotation to keep.', self.nvim.text())

  def test_rejects_invalid_file_range_side_and_layout(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'requested.lua'
      filename.write_text('only line\n')
      missing = Path(directory) / 'missing.lua'
      self.nvim.nvim.command('vsplit')

      cases = [
        ([str(missing), [1, 1], 'message', 'left'], 'readable file'),
        ([str(filename), [0, 1], 'message', 'left'], 'range'),
        ([str(filename), [2, 1], 'message', 'left'], 'range'),
        ([str(filename), [1, 2], 'message', 'left'], 'range'),
        ([str(filename), [1, 1], 'message', 'middle'], 'side'),
      ]
      for arguments, error in cases:
        with self.subTest(arguments=arguments), self.assertRaisesRegex(pynvim.NvimError, error):
          self.nvim.nvim.exec_lua(
            "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
            arguments,
          )

      self.showme(filename, 'annotation that survives rejection', 'left')
      with self.assertRaisesRegex(pynvim.NvimError, 'readable file'):
        self.showme(missing, 'replacement that must not render', 'left')
      self.nvim.flush()
      self.assertIn('annotation that survives rejection', self.nvim.text())
      self.assertNotIn('replacement that must not render', self.nvim.text())

      self.nvim.nvim.command('only')
      with self.assertRaisesRegex(pynvim.NvimError, 'side-by-side'):
        self.showme(filename, 'message', 'left')

  def test_preserves_displaced_unsaved_buffer_when_hidden_is_off(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'requested.lua'
      filename.write_text('requested file content\n')
      self.nvim.nvim.command('set nohidden')
      self.nvim.nvim.command('vsplit')
      windows = self.nvim.nvim.exec_lua(
        """
        local wins = vim.api.nvim_tabpage_list_wins(0)
        table.sort(wins, function(left, right)
          return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
        end)
        return wins
        """
      )
      old_buffer = self.nvim.nvim.request('nvim_win_get_buf', windows[0])
      self.nvim.nvim.request(
        'nvim_buf_set_lines', old_buffer, 0, -1, False, ['unsaved displaced content']
      )
      replacement = self.nvim.nvim.request('nvim_create_buf', True, False)
      self.nvim.nvim.request('nvim_win_set_buf', windows[1], replacement)

      self.showme(filename, 'requested annotation', 'left')
      self.nvim.nvim.request('nvim_win_set_buf', windows[1], old_buffer)
      self.nvim.nvim.request('nvim_set_current_win', windows[1])
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('unsaved displaced content', rendered)

  def test_loads_existing_unloaded_buffer_without_reloading_unsaved_edits(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'three-lines.lua'
      filename.write_text('one\ntwo\nthree\n')
      self.nvim.nvim.command('vsplit')
      buffer = self.nvim.nvim.exec_lua('local args = ...; return vim.fn.bufadd(args[1])', [str(filename)])

      self.showme(filename, 'loaded third line', 'left', [3, 3])
      self.nvim.nvim.exec_lua(
        "local args = ...; vim.api.nvim_buf_set_lines(args[1], 1, 2, false, { 'unsaved two' })",
        [buffer],
      )
      self.showme(filename, 'loaded unsaved line', 'left', [2, 2])
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('three', rendered)
      self.assertIn('unsaved two', rendered)

  def test_preserves_modified_wipe_buffer_when_hidden_is_on(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'requested.lua'
      filename.write_text('requested file content\n')
      self.nvim.nvim.command('set hidden')
      self.nvim.nvim.command('vsplit')
      windows = self.nvim.nvim.exec_lua(
        """
        local wins = vim.api.nvim_tabpage_list_wins(0)
        table.sort(wins, function(left, right)
          return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
        end)
        return wins
        """
      )
      old_buffer = self.nvim.nvim.request('nvim_win_get_buf', windows[0])
      self.nvim.nvim.request(
        'nvim_buf_set_lines', old_buffer, 0, -1, False, ['modified wipe content']
      )
      self.nvim.nvim.exec_lua(
        "local args = ...; vim.bo[args[1]].bufhidden = 'wipe'", [old_buffer]
      )
      replacement = self.nvim.nvim.request('nvim_create_buf', True, False)
      self.nvim.nvim.request('nvim_win_set_buf', windows[1], replacement)

      self.showme(filename, 'requested annotation', 'left')
      self.assertTrue(self.nvim.nvim.request('nvim_buf_is_valid', old_buffer))
      self.assertTrue(self.nvim.nvim.request('nvim_buf_get_option', old_buffer, 'modified'))
      self.nvim.nvim.request('nvim_win_set_buf', windows[1], old_buffer)
      self.nvim.nvim.request('nvim_set_current_win', windows[1])
      self.nvim.flush()

      self.assertIn('modified wipe content', self.nvim.text())

  def test_tour_message_panels_fill_text_area_with_gutters_and_resize(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'shared.lua'
      filename.write_text('shared source\n')
      self.nvim.nvim.command('set number signcolumn=yes')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', {
          fg = '#010203', bg = '#a1b2c3',
        })
        """
      )
      description = (
        'left short\n\nleft wide 界 words wrap across the now wider description panel'
      )
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])",
        [[{
          'left': {'filename': str(filename), 'range': [1, 1], 'message': description},
          'right': {
            'filename': str(filename), 'range': [1, 1],
            'message': 'right independent description',
          },
        }]],
      )
      self.nvim.flush()
      windows = self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(left, right)
          return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
        end)
        return windows
        """
      )
      background = 0xA1B2C3

      for index, (window, text) in enumerate(
        zip(windows, ('left short', 'right independent'))
      ):
        row = self.nvim.row_for_window_text(window, text)
        self.assertTrue(self.nvim.text_area_has_background(row, window, background))
        window_left, text_left, right = self.nvim.window_text_area_bounds(window)
        self.assertTrue(
          all(
            self.nvim.highlight_attributes.get(attribute, {}).get('background') != background
            for attribute in self.nvim.attributes[row][window_left:text_left]
          )
        )
        if index + 1 < len(windows):
          next_window_left, _, _ = self.nvim.window_text_area_bounds(windows[index + 1])
          self.assertTrue(
            all(
              self.nvim.highlight_attributes.get(attribute, {}).get('background') != background
              for attribute in self.nvim.attributes[row][right:next_window_left]
            )
          )

      left_short_row = self.nvim.row_for_window_text(windows[0], 'left short')
      self.assertTrue(
        self.nvim.text_area_has_background(left_short_row + 1, windows[0], background)
      )
      self.assertIn('界', self.nvim.text())
      initial_wrapped_row = self.nvim.row_for_window_text(windows[0], 'left wide 界')
      initial_left, initial_right = self.nvim.text_area_bounds(windows[0])
      initial_wrapping = ''.join(self.nvim.rows[initial_wrapped_row][initial_left:initial_right])
      for window in windows:
        footer_row = self.nvim.row_for_window_text(window, 'Step 1/1')
        self.assertTrue(self.nvim.text_area_has_background(footer_row, window, background))

      self.nvim.nvim.request('nvim_ui_try_resize', 120, 20)
      self.nvim.nvim.command('wincmd =')
      self.nvim.flush()
      self.assertIn('界', self.nvim.text())
      self.assertIn('right independent description', self.nvim.text())
      wider_wrapped_row = self.nvim.row_for_window_text(windows[0], 'left wide 界')
      wider_left, wider_right = self.nvim.text_area_bounds(windows[0])
      wider_wrapping = ''.join(self.nvim.rows[wider_wrapped_row][wider_left:wider_right])
      self.assertNotEqual(initial_wrapping, wider_wrapping)
      for window, text in zip(windows, ('left short', 'right independent')):
        row = self.nvim.row_for_window_text(window, text)
        self.assertTrue(self.nvim.text_area_has_background(row, window, background))

      self.nvim.nvim.request('nvim_ui_try_resize', 60, 20)
      self.nvim.nvim.command('wincmd =')
      self.nvim.flush()
      self.assertIn('界', self.nvim.text())
      for window, text in zip(windows, ('left short', 'right independent')):
        row = self.nvim.row_for_window_text(window, text)
        self.assertTrue(self.nvim.text_area_has_background(row, window, background))
      left_short_row = self.nvim.row_for_window_text(windows[0], 'left short')
      self.assertTrue(
        self.nvim.text_area_has_background(left_short_row + 1, windows[0], background)
      )
      for window in windows:
        footer_row = self.nvim.row_for_window_text(window, 'Step 1/1')
        self.assertTrue(self.nvim.text_area_has_background(footer_row, window, background))

  def test_wraps_message_and_rewraps_after_resize(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'requested.lua'
      filename.write_text('requested file content\n')
      message = 'one two three four five six seven eight nine ten eleven twelve thirteen fourteen'
      self.nvim.nvim.command('set number signcolumn=yes')
      self.nvim.nvim.command('vsplit')

      self.showme(filename, message, 'left')
      self.nvim.flush()
      self.assertIn('thirteen fourteen', self.nvim.text())

      self.nvim.nvim.request('nvim_ui_try_resize', 120, 20)
      self.nvim.flush()
      self.assertIn('thirteen fourteen', self.nvim.text())

  def test_message_rewraps_when_sign_gutter_appears_without_a_resize(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'initial-layout.lua'
      filename.write_text('source\n')
      message = 'start0001 ' + ' '.join(f'word{index:04}' for index in range(2, 25))
      self.nvim.nvim.command('set number signcolumn=auto')
      self.nvim.nvim.command('sign define ShowMeTestSign text=!! texthl=ErrorMsg')
      self.showme(filename, message, 'left')
      self.nvim.flush()
      windows = self.nvim.nvim.request('nvim_tabpage_list_wins', 0)
      window = min(windows, key=lambda win: self.nvim.nvim.request('nvim_win_get_position', win)[1])
      initial_width = self.nvim.nvim.request('nvim_win_get_width', window)
      _, initial_text_left, _ = self.nvim.window_text_area_bounds(window)
      left, right = self.nvim.text_area_bounds(window)
      self.assertIn(message, ' '.join(''.join(row[left:right]).strip() for row in self.nvim.rows))

      # Diagnostics and other plugins can add signs after the first layout is drawn.
      buffer = self.nvim.nvim.request('nvim_win_get_buf', window)
      self.nvim.nvim.call('sign_place', 0, 'showme-test', 'ShowMeTestSign', buffer, {'lnum': 1})
      self.nvim.flush()
      self.nvim.flush()
      _, text_left, _ = self.nvim.window_text_area_bounds(window)
      self.assertGreater(text_left, initial_text_left)
      self.assertEqual(initial_width, self.nvim.nvim.request('nvim_win_get_width', window))
      left, right = self.nvim.text_area_bounds(window)
      self.assertIn(message, ' '.join(''.join(row[left:right]).strip() for row in self.nvim.rows))
      self.assertEqual('source\n', filename.read_text())

  def test_tour_scene_panels_reflow_with_gutters_without_losing_comments_or_range(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      first = Path(directory) / 'first.lua'
      second = Path(directory) / 'second.lua'
      first.write_text('first source\n')
      second.write_text('second source\n')
      words = ' '.join(f'word{index:04}' for index in range(2, 17))
      messages = ['left00001 ' + words, 'right0001 ' + words]
      self.nvim.nvim.command('set number signcolumn=auto')
      self.nvim.nvim.command('sign define ShowMeTestSign text=!! texthl=ErrorMsg')
      self.nvim.nvim.exec_lua("vim.api.nvim_set_hl(0,'CursorLine',{bg='#123456'}); vim.api.nvim_set_hl(0,'DiagnosticVirtualTextInfo',{bg='#a1b2c3'})")
      scenes = [
        {'left': {'filename': str(first), 'range': [1, 1], 'message': 'first scene'}},
        {side: {'filename': str(second), 'range': [1, 1], 'message': message}
         for side, message in zip(('left', 'right'), messages)},
      ]
      report_id = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
      self.nvim.flush()
      self.nvim.nvim.exec_lua("require('misc').TourNext()")
      self.nvim.nvim.command('wincmd h')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('saved user comment')"))
      buffer = self.nvim.nvim.request('nvim_get_current_buf')
      self.nvim.nvim.request('nvim_buf_set_lines', buffer, 0, 0, False, ['inserted source'])
      self.nvim.flush()
      windows = sorted(self.nvim.nvim.request('nvim_tabpage_list_wins', 0),
                       key=lambda win: self.nvim.nvim.request('nvim_win_get_position', win)[1])
      widths = [self.nvim.nvim.request('nvim_win_get_width', win) for win in windows]
      for show_sign in (True, False):
        if show_sign:
          self.nvim.nvim.call('sign_place', 0, 'showme-test', 'ShowMeTestSign', buffer, {'lnum': 2})
        else:
          self.nvim.nvim.call('sign_unplace', 'showme-test', {'buffer': buffer})
        self.nvim.flush()
        self.nvim.flush()
        self.assertEqual(widths, [self.nvim.nvim.request('nvim_win_get_width', win) for win in windows])
        for window, message in zip(windows, messages):
          left, right = self.nvim.text_area_bounds(window)
          text = ' '.join(''.join(row[left:right]).strip() for row in self.nvim.rows)
          self.assertIn(message, text)
          self.assertIn('saved user comment', text)
          for label in ('left00001' if window == windows[0] else 'right0001', 'saved user comment', 'Step 2/2'):
            row = self.nvim.row_for_window_text(window, label)
            self.assertTrue(self.nvim.text_area_has_background(row, window, 0xA1B2C3))
          row = self.nvim.row_for_window_text(window, 'second source')
          self.assertTrue(self.nvim.text_area_has_background(row, window, 0x123456))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
      self.assertEqual(['saved user comment'], [comment['message'] for comment in report['comments']])
      self.assertEqual({'first': 1, 'last': 1}, report['comments'][0]['range'])
      self.assertEqual(['inserted source', 'second source'], self.nvim.nvim.request('nvim_buf_get_lines', buffer, 0, -1, False))
      self.assertEqual('second source\n', second.read_text())

  def test_pending_reflow_does_not_revive_cleared_closed_or_replaced_annotations(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'pending-layout.lua'
      filename.write_text('alpha\nbeta\n')
      self.nvim.nvim.command('set number signcolumn=auto')
      self.nvim.nvim.command('sign define ShowMeTestSign text=!! texthl=ErrorMsg')
      for action in ('clear', 'stop', 'replace'):
        with self.subTest(action=action):
          self.nvim.nvim.call('sign_unplace', 'showme-test')
          self.showme(filename, 'obsolete message', 'left')
          self.nvim.nvim.command('wincmd h')
          self.nvim.flush()
          self.nvim.nvim.exec_lua(
            """
            local action,filename=...
            vim.fn.sign_place(0,'showme-test','ShowMeTestSign',0,{lnum=1})
            vim.cmd('redraw')
            if action=='clear' then
              require('misc').ClearShowMe('left')
            elseif action=='stop' then
              require('misc').TourStop()
            else
              require('misc').ShowMe(filename,{2,2},'replacement message','left')
            end
            """, action, str(filename)
          )
          window = self.nvim.nvim.request('nvim_get_current_win')
          self.nvim.flush()
          self.nvim.flush()
          self.assertNotIn('obsolete message', self.nvim.text())
          self.assertEqual(window, self.nvim.nvim.request('nvim_get_current_win'))
          if action == 'replace':
            self.assertIn('replacement message', self.nvim.text())
          self.nvim.nvim.exec_lua("require('misc').TourStop()")
      self.assertEqual('alpha\nbeta\n', filename.read_text())
      self.assertEqual([], self.nvim.nvim.exec_lua("return require('misc').GetTourComments()"))

  def test_reveals_folded_eof_range_and_places_message_below_it(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'folded.lua'
      filename.write_text('-- {{{\ninside folded range\n-- }}}\nlast eof line\n')
      self.nvim.nvim.command('set foldmethod=marker')
      self.nvim.nvim.command('vsplit')

      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(filename), [2, 4], 'after eof range', 'left'],
      )
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('inside folded range', rendered)
      self.assertIn('last eof line', rendered)
      self.assertIn('after eof range', rendered)

  def test_resize_ignores_shortened_or_replaced_annotation_buffer(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'shortened.lua'
      filename.write_text('one\ntwo\nthree\n')
      self.nvim.nvim.command('vsplit')
      self.showme(filename, 'stale annotation', 'left', [1, 3])
      buffer = self.nvim.nvim.exec_lua('local args = ...; return vim.fn.bufnr(args[1])', [str(filename)])
      self.nvim.nvim.request('nvim_buf_set_lines', buffer, 1, -1, False, [])
      self.nvim.nvim.request('nvim_ui_try_resize', 100, 20)
      self.nvim.flush()
      self.assertNotIn('stale annotation', self.nvim.text())

      windows = self.nvim.nvim.exec_lua(
        """
        local wins = vim.api.nvim_tabpage_list_wins(0)
        table.sort(wins, function(left, right)
          return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
        end)
        return wins
        """
      )
      replacement = self.nvim.nvim.request('nvim_create_buf', True, False)
      self.nvim.nvim.request('nvim_buf_set_lines', replacement, 0, -1, False, ['replacement'])
      self.nvim.nvim.request('nvim_win_set_buf', windows[0], replacement)
      self.nvim.nvim.request('nvim_ui_try_resize', 80, 20)
      self.nvim.flush()

      self.assertIn('replacement', self.nvim.text())
      self.assertNotIn('stale annotation', self.nvim.text())

  def test_paints_cursorline_background_across_source_and_blank_lines(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'background.lua'
      filename.write_text('painted source line\n\nunpainted source line\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        "vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456', ctermbg = 17 })"
      )

      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(filename), [1, 2], 'background annotation', 'left'],
      )
      self.nvim.flush()

      painted_row = self.nvim.row_for('painted source line')
      self.assertTrue(self.nvim.left_text_width_has_background(painted_row, 0x123456))
      self.assertTrue(self.nvim.left_text_width_has_background(painted_row + 1, 0x123456))
      background = self.nvim.nvim.exec_lua(
        "return vim.api.nvim_get_hl(0, { name = 'MiscShowMeBackground', link = false })"
      )
      self.assertEqual(17, background.get('ctermbg'))

      self.nvim.nvim.exec_lua(
        """
        vim.cmd 'highlight clear'
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#654321', ctermbg = 53 })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()
      painted_row = self.nvim.row_for('painted source line')
      self.assertTrue(self.nvim.left_text_width_has_background(painted_row, 0x654321))
      self.assertTrue(self.nvim.left_text_width_has_background(painted_row + 1, 0x654321))
      background = self.nvim.nvim.exec_lua(
        "return vim.api.nvim_get_hl(0, { name = 'MiscShowMeBackground', link = false })"
      )
      self.assertEqual(53, background.get('ctermbg'))

      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { fg = '#abcdef' })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()
      self.assertFalse(self.nvim.row_has_background(painted_row, 0x654321))

  def test_annotation_messages_and_tour_footer_follow_diagnostic_info(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'tour.lua'
      filename.write_text('tour source\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', {
          fg = '#a1b2c3', bg = '#d4e5f6', italic = true,
        })
        """
      )
      self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])",
        [[{'left': {'filename': str(filename), 'range': [1, 1], 'message': 'tour description'}}]],
      )
      self.nvim.flush()

      for text in ('tour description', 'Step 1/1'):
        with self.subTest(text=text):
          attributes = self.nvim.attributes_for(text)
          self.assertEqual(0xA1B2C3, attributes.get('foreground'))
          self.assertEqual(0xD4E5F6, attributes.get('background'))
          self.assertTrue(attributes.get('italic'))

      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', {
          fg = '#102030', bg = '#405060', bold = true,
        })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()

      for text in ('tour description', 'Step 1/1'):
        with self.subTest(text=text):
          attributes = self.nvim.attributes_for(text)
          self.assertEqual(0x102030, attributes.get('foreground'))
          self.assertEqual(0x405060, attributes.get('background'))
          self.assertTrue(attributes.get('bold'))
          self.assertNotIn('italic', attributes)

  def test_default_custom_showme_highlights_before_display_survive_colorscheme(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'default-custom-before.lua'
      filename.write_text('default custom before source\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#234567' })
        vim.api.nvim_set_hl(0, 'MiscShowMeBackground', {
          default = true, bg = '#345678',
        })
        vim.api.nvim_set_hl(0, 'MiscShowMeMessage', {
          default = true, fg = '#456789', bg = '#56789a', underline = true,
        })
        """
      )
      self.showme(filename, 'default custom before message', 'left')
      self.nvim.flush()

      source_row = self.nvim.row_for('default custom before source')
      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('default custom before message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#6789ab' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#789abc' })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()

      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('default custom before message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

  def test_default_custom_showme_highlights_after_display_survive_colorscheme(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'default-custom-after.lua'
      filename.write_text('default custom after source\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#234567' })
        """
      )
      self.showme(filename, 'default custom after message', 'left')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'MiscShowMeBackground', {
          default = true, force = true, bg = '#345678',
        })
        vim.api.nvim_set_hl(0, 'MiscShowMeMessage', {
          default = true, force = true, fg = '#456789', bg = '#56789a', underline = true,
        })
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#6789ab' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#789abc' })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()

      source_row = self.nvim.row_for('default custom after source')
      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('default custom after message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

  def test_custom_showme_highlights_defined_before_display_survive_colorscheme(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'custom-before.lua'
      filename.write_text('custom before source\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#234567' })
        vim.api.nvim_set_hl(0, 'MiscShowMeBackground', { bg = '#345678' })
        vim.api.nvim_set_hl(0, 'MiscShowMeMessage', {
          fg = '#456789', bg = '#56789a', underline = true,
        })
        """
      )
      self.showme(filename, 'custom before message', 'left')
      self.nvim.flush()

      source_row = self.nvim.row_for('custom before source')
      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('custom before message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#6789ab' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#789abc' })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()

      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('custom before message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

  def test_custom_showme_highlights_defined_after_display_survive_colorscheme(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'custom-after.lua'
      filename.write_text('custom after source\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#234567' })
        """
      )
      self.showme(filename, 'custom after message', 'left')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'MiscShowMeBackground', { bg = '#345678' })
        vim.api.nvim_set_hl(0, 'MiscShowMeMessage', {
          fg = '#456789', bg = '#56789a', underline = true,
        })
        vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#6789ab' })
        vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextInfo', { fg = '#789abc' })
        vim.api.nvim_exec_autocmds('ColorScheme', { modeline = false })
        """
      )
      self.nvim.flush()

      source_row = self.nvim.row_for('custom after source')
      self.assertTrue(self.nvim.left_text_width_has_background(source_row, 0x345678))
      attributes = self.nvim.attributes_for('custom after message')
      self.assertEqual(0x456789, attributes.get('foreground'))
      self.assertEqual(0x56789A, attributes.get('background'))
      self.assertTrue(attributes.get('underline'))

  def test_scrolloff_does_not_hide_range_or_message(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'long.lua'
      filename.write_text(''.join(f'line {index}\n' for index in range(1, 201)))
      self.nvim.nvim.command('set scrolloff=5')
      self.nvim.nvim.command('vsplit')

      self.showme(filename, 'visible explanation', 'left', [183, 184])
      self.nvim.flush()

      rendered = self.nvim.text()
      self.assertIn('line 183', rendered)
      self.assertIn('line 184', rendered)
      self.assertIn('visible explanation', rendered)
      self.assertEqual(5, self.nvim.nvim.eval('&scrolloff'))

  def test_annotation_copies_only_cursorline_background_over_syntax(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      filename = Path(directory) / 'syntax.lua'
      filename.write_text('syntax token\nunannotated syntax token\n')
      self.nvim.nvim.command('vsplit')
      self.nvim.nvim.exec_lua(
        """
        vim.api.nvim_set_hl(0, 'CursorLine', {
          fg = '#fedcba', bg = '#456789', italic = true, underline = true, reverse = true,
        })
        vim.api.nvim_set_hl(0, 'ShowMeSyntaxTest', {
          fg = '#112233', bold = true, italic = false,
        })
        """
      )
      self.showme(filename, 'syntax annotation', 'left')
      self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(left, right)
          return vim.api.nvim_win_get_position(left)[2] < vim.api.nvim_win_get_position(right)[2]
        end)
        vim.api.nvim_win_call(windows[1], function()
          vim.api.nvim_buf_add_highlight(0, 0, 'ShowMeSyntaxTest', 0, 0, -1)
          vim.api.nvim_buf_add_highlight(0, 0, 'ShowMeSyntaxTest', 1, 0, -1)
        end)
        """
      )
      self.nvim.nvim.command('redraw!')
      self.nvim.flush()

      plain_row = self.nvim.row_for('unannotated syntax token')
      column = ''.join(self.nvim.rows[plain_row]).index('syntax token')
      attribute = self.nvim.attributes[plain_row][column]
      self.assertEqual(0x112233, self.nvim.highlight_attributes[attribute].get('foreground'))

      source_row = self.nvim.row_for('syntax token')
      column = ''.join(self.nvim.rows[source_row]).index('syntax token')
      attribute = self.nvim.attributes[source_row][column]
      rgb = self.nvim.highlight_attributes[attribute]
      self.assertEqual(0x112233, rgb.get('foreground'))
      self.assertEqual(0x456789, rgb.get('background'))
      self.assertTrue(rgb.get('bold'))
      self.assertNotIn('italic', rgb)
      self.assertNotIn('underline', rgb)
      self.assertNotIn('reverse', rgb)


  def test_programmatic_annotation_is_reported_after_standalone_quit_and_acknowledged(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'feedback.lua'
      source.write_text('captured source\n')

      report_id = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(source), [1, 1], 'explanation', 'left'],
      )
      self.assertIsInstance(report_id, str)
      source_buffer = self.nvim.nvim.exec_lua("return vim.fn.bufnr((...)[1])", [str(source)])
      self.nvim.nvim.request(
        'nvim_buf_set_text', source_buffer, 0, 0, 0, len('captured source'), ['unsaved metadata snapshot']
      )
      self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(a, b)
          return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
        end)
        vim.api.nvim_set_current_win(windows[1])
        return require('misc').AnnotateShowMe('ready for review')
        """
      )
      self.nvim.nvim.input('\\tq')

      reports = self.nvim.nvim.exec_lua("return require('misc').GetTourComments()")
      self.assertEqual(1, len(reports))
      self.assertEqual(report_id, reports[0]['id'])
      self.assertEqual('completed', reports[0]['status'])
      self.assertEqual('ready for review', reports[0]['comments'][0]['message'])
      self.assertEqual('unsaved metadata snapshot', reports[0]['comments'][0]['excerpt'])
      self.assertEqual(
        ['unsaved metadata snapshot'],
        self.nvim.nvim.request('nvim_buf_get_lines', source_buffer, 0, -1, False),
      )
      self.assertTrue(
        self.nvim.nvim.exec_lua(
          "local args = ...; return require('misc').AcknowledgeTourComments(args[1])",
          [report_id],
        )
      )
      self.assertEqual([], self.nvim.nvim.exec_lua("return require('misc').GetTourComments()"))
      self.assertEqual(
        '[]', self.nvim.nvim.exec_lua("return vim.json.encode(require('misc').GetTourComments())")
      )


  def test_tour_comments_survive_revisit_and_render_before_the_footer(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'shared.lua'
      source.write_text('first\nsecond\n')
      scenes = [
        {
          'left': {'filename': str(source), 'range': [1, 1], 'message': 'left explanation'},
          'right': {'filename': str(source), 'range': [2, 2], 'message': 'right explanation'},
        },
        {'left': {'filename': str(source), 'range': [2, 2], 'message': 'second explanation'}},
      ]
      report_id = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').Tour(args[1])", [scenes]
      )
      windows = self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(a, b)
          return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
        end)
        return windows
        """
      )
      for window, message in zip(windows, ('left feedback', 'right feedback')):
        self.nvim.nvim.request('nvim_set_current_win', window)
        self.assertTrue(
          self.nvim.nvim.exec_lua(
            "local args = ...; return require('misc').AnnotateShowMe(args[1])", [message]
          )
        )
      self.nvim.flush()
      rendered = self.nvim.text()
      self.assertLess(rendered.index('left feedback'), rendered.index('Step 1/2'))
      self.assertLess(rendered.index('right feedback'), rendered.index('Step 1/2'))

      self.nvim.nvim.exec_lua("return require('misc').TourNext()")
      self.nvim.nvim.exec_lua("return require('misc').TourPrev()")
      self.nvim.flush()
      self.assertIn('left feedback', self.nvim.text())
      self.assertIn('right feedback', self.nvim.text())
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")

      report = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').GetTourComments(args[1])", [report_id]
      )[0]
      self.assertEqual({'first': 1, 'last': 1}, report['comments'][0]['range'])
      self.assertEqual({'left', 'right'}, {comment['side'] for comment in report['comments']})

  def test_outbox_keeps_completed_reports_and_returns_independent_filtered_copies(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'outbox.lua'
      source.write_text('source\n')
      first = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(source), [1, 1], 'first explanation', 'left'],
      )
      self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
        vim.api.nvim_set_current_win(windows[1])
        return require('misc').AnnotateShowMe('first comment')
        """
      )
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")
      second = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(source), [1, 1], 'second explanation', 'left'],
      )
      self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
        vim.api.nvim_set_current_win(windows[1])
        return require('misc').AnnotateShowMe('second comment')
        """
      )
      self.nvim.nvim.exec_lua("return require('misc').TourStop()")

      self.assertEqual(
        [first, second],
        [report['id'] for report in self.nvim.nvim.exec_lua("return require('misc').GetTourComments()")],
      )
      self.assertEqual(
        'first comment',
        self.nvim.nvim.exec_lua(
          """
          local args = ...
          local copied = require('misc').GetTourComments(args[1])
          copied[1].comments[1].message = 'mutated caller copy'
          return require('misc').GetTourComments(args[1])[1].comments[1].message
          """,
          [first],
        ),
      )
      self.assertTrue(
        self.nvim.nvim.exec_lua(
          "local args = ...; return require('misc').AcknowledgeTourComments(args[1])", [first]
        )
      )
      self.assertTrue(
        self.nvim.nvim.exec_lua(
          "local args = ...; return require('misc').AcknowledgeTourComments(args[1])", [first]
        )
      )
      self.assertEqual(
        [second],
        [report['id'] for report in self.nvim.nvim.exec_lua("return require('misc').GetTourComments()")],
      )

  def test_replacing_a_tour_cancels_its_draft_without_touching_the_new_report(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'input.lua'
      source.write_text('source\n')
      scenes = [{'left': {'filename': str(source), 'range': [1, 1], 'message': 'explanation'}}]
      report_id = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
      self.nvim.nvim.command('wincmd h')
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('discard this unfinished draft')
      self.nvim.flush()
      editor = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')

      new_id = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
      self.assertNotEqual(report_id, new_id)
      self.assertFalse(self.nvim.nvim.request('nvim_win_is_valid', editor))
      self.assertFalse(self.nvim.nvim.request('nvim_buf_is_valid', draft))
      self.nvim.nvim.command('wincmd h')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('new report note')"))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      self.nvim.flush()
      self.assertEqual([], self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)", report_id))
      reports = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)", new_id)
      self.assertEqual(['new report note'], [comment['message'] for comment in reports[0]['comments']])


  def test_annotation_mapping_accepts_actual_keyboard_input_and_ignores_blank_input(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'keyboard.lua'
      source.write_text('keyboard source\n')
      report_id = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').ShowMe(args[1], args[2], args[3], args[4])",
        [str(source), [1, 1], 'keyboard explanation', 'left'],
      )
      self.nvim.nvim.exec_lua(
        """
        local windows = vim.api.nvim_tabpage_list_wins(0)
        table.sort(windows, function(a, b) return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2] end)
        vim.api.nvim_set_current_win(windows[1])
        """
      )
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('keyboard feedback\x1b\r')
      self.nvim.flush()
      self.nvim.nvim.input('\\ta')
      self.nvim.flush()
      self.nvim.nvim.request('nvim_buf_set_lines', 0, 0, -1, False, ['   '])
      self.nvim.nvim.input('\x1b\r')
      self.nvim.flush()
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('discard this draft\x1b')
      self.nvim.flush()
      self.assertEqual('editor', self.nvim.nvim.request('nvim_win_get_config', 0)['relative'])
      self.nvim.nvim.input('q')
      self.nvim.flush()
      self.nvim.nvim.input('\\tq')

      comments = self.nvim.nvim.exec_lua(
        "local args = ...; return require('misc').GetTourComments(args[1])[1].comments",
        [report_id],
      )
      self.assertEqual(['keyboard feedback'], [comment['message'] for comment in comments])


  def test_standalone_comments_follow_their_range_not_the_reused_pane(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'ranges.lua'
      source.write_text('first source\nsecond source\n')
      show = "local a = ...; return require('misc').ShowMe(a[1], a[2], a[3], 'left')"
      first_id = self.nvim.nvim.exec_lua(show, [str(source), [1, 1], 'first explanation'])
      self.nvim.nvim.command('wincmd h')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('note for first')"))

      second_id = self.nvim.nvim.exec_lua(show, [str(source), [2, 2], 'second explanation'])
      self.assertEqual(first_id, second_id)
      self.nvim.flush()
      self.assertNotIn('note for first', self.nvim.text())

      self.nvim.nvim.exec_lua(show, [str(source), [1, 1], 'first explanation again'])
      self.nvim.flush()
      self.assertIn('note for first', self.nvim.text())
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      reports = self.nvim.nvim.exec_lua("return require('misc').GetTourComments()")
      self.assertEqual([first_id], [report['id'] for report in reports])
      self.assertEqual({'first': 1, 'last': 1}, reports[0]['comments'][0]['range'])
      self.assertEqual('first source', reports[0]['comments'][0]['excerpt'])


  def test_range_comment_refreshes_both_highlights_and_snapshot_after_source_edits(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'moving.lua'
      source.write_text('before\ntarget\nafter\n')
      self.nvim.nvim.exec_lua("vim.api.nvim_set_hl(0, 'CursorLine', { bg = '#123456' })")
      report_id = self.nvim.nvim.exec_lua(
        "local a = ...; return require('misc').ShowMe(a[1], {2, 2}, 'target explanation', 'left')",
        [str(source)],
      )
      self.nvim.nvim.exec_lua(
        "require('misc').ShowMe(..., {2, 2}, 'same target', 'right')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('before source edit')"))
      self.nvim.nvim.exec_lua("vim.api.nvim_buf_set_lines(0, 0, 0, false, {'inserted'})")
      source_buffer = self.nvim.nvim.request('nvim_get_current_buf')
      before_cursor = self.nvim.nvim.request('nvim_win_get_cursor', 0)
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('note on target')"))
      self.assertEqual(before_cursor, self.nvim.nvim.request('nvim_win_get_cursor', 0))
      self.nvim.nvim.command('wincmd l')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('note from right')"))
      self.nvim.nvim.command('redraw!')
      self.nvim.flush()
      self.assertTrue(self.nvim.left_text_width_has_background(self.nvim.row_for('target'), 0x123456))

      self.nvim.nvim.exec_lua(
        "vim.o.hidden = true; vim.api.nvim_win_set_buf(0, vim.api.nvim_create_buf(true, false))"
      )
      self.assertFalse(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('wrong file')"))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua(
        "return require('misc').GetTourComments(...)[1]", report_id
      )
      self.assertEqual(1, len(report['comments']))
      self.assertEqual({'first': 3, 'last': 3}, report['comments'][0]['range'])
      self.assertEqual('target', report['comments'][0]['excerpt'])
      self.assertEqual('note from right', report['comments'][0]['message'])
      self.assertEqual(
        ['inserted', 'before', 'target', 'after'],
        self.nvim.nvim.request('nvim_buf_get_lines', source_buffer, 0, -1, False),
      )
      self.assertEqual('before\ntarget\nafter\n', source.read_text())


  def test_standalone_composition_keeps_its_frozen_annotation_and_quit_keys(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'keys.lua'
      source.write_text('first\nsecond\n')
      self.nvim.nvim.exec_lua('vim.g.mapleader = ...', '\\')
      first_id = self.nvim.nvim.exec_lua(
        "local a = ...; return require('misc').ShowMe(a[1], {1, 1}, 'left', 'left')",
        [str(source)],
      )
      self.nvim.nvim.exec_lua('vim.g.mapleader = ...', ',')
      second_id = self.nvim.nvim.exec_lua(
        "local a = ...; return require('misc').ShowMe(a[1], {2, 2}, 'right', 'right')",
        [str(source)],
      )
      self.assertEqual(first_id, second_id)
      self.assertEqual(1, self.nvim.nvim.exec_lua(
        "return vim.fn.maparg(..., 'n', false, true).buffer or 0", '\\ta'
      ))
      self.assertEqual(0, self.nvim.nvim.exec_lua(
        "return vim.fn.maparg(..., 'n', false, true).buffer or 0", ',ta'
      ))
      self.nvim.nvim.input('\\tq')
      self.nvim.flush()
      self.assertEqual(1, self.nvim.nvim.exec_lua('return #vim.api.nvim_list_tabpages()'))


  def test_feedback_is_finalized_once_across_all_presentation_endings(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'endings.lua'
      source.write_text('first source\nsecond source\n')
      scenes = [{'left': {'filename': str(source), 'range': [1, 1], 'message': 'explanation'}}]
      expected = {
        'finish': 'finished', 'stop': 'stopped', 'manual': 'closed',
        'background': 'closed', 'replace': 'replaced', 'clear': 'cleared',
        'interrupt': 'interrupted', 'invalid_then_quit': 'stopped',
      }
      completed = []
      for ending, reason in expected.items():
        with self.subTest(ending=ending):
          origin = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()')
          report_id = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
          self.nvim.nvim.command('wincmd h')
          self.assertTrue(self.nvim.nvim.exec_lua(
            "return require('misc').AnnotateShowMe(...)", 'comment ' + ending
          ))
          open_reports = self.nvim.nvim.exec_lua(
            "return require('misc').GetTourComments(...)", report_id
          )
          self.assertEqual(['in_progress'], [report['status'] for report in open_reports])
          self.assertEqual(
            ['comment ' + ending], [c['message'] for c in open_reports[0]['comments']]
          )
          self.assertFalse(self.nvim.nvim.exec_lua(
            "return require('misc').AcknowledgeTourComments(...)", report_id
          ))
          if ending == 'finish':
            self.nvim.nvim.exec_lua("require('misc').TourNext()")
          elif ending == 'stop':
            self.nvim.nvim.exec_lua("require('misc').TourStop()")
          elif ending == 'manual':
            self.nvim.nvim.command('tabclose')
          elif ending == 'background':
            number = self.nvim.nvim.exec_lua('return vim.api.nvim_tabpage_get_number(0)')
            self.nvim.nvim.exec_lua('vim.api.nvim_set_current_tabpage(...)', origin)
            self.nvim.nvim.command(f'tabclose! {number}')
          elif ending == 'replace':
            replacement = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
            self.assertNotEqual(report_id, replacement)
          elif ending == 'clear':
            self.nvim.nvim.exec_lua("require('misc').ClearShowMe()")
            self.assertNotEqual(origin, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()'))
          elif ending == 'interrupt':
            replacement = self.nvim.nvim.exec_lua(
              "return require('misc').ShowMe(..., {2, 2}, 'standalone', 'right')", str(source)
            )
            self.assertNotEqual(report_id, replacement)
          else:
            self.nvim.nvim.exec_lua('vim.api.nvim_set_current_tabpage(...)', origin)
            invalid = [{'left': {'filename': str(source), 'range': [9, 9], 'message': 'invalid'}}]
            with self.assertRaises(pynvim.NvimError):
              self.nvim.nvim.exec_lua("require('misc').Tour(...)", invalid)
            self.assertEqual(origin, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()'))
            self.assertEqual(['in_progress'], [report['status'] for report in self.nvim.nvim.exec_lua(
              "return require('misc').GetTourComments(...)", report_id
            )])
            self.nvim.nvim.exec_lua("require('misc').TourStop()")

          current = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()')
          reports = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)", report_id)
          self.assertEqual(current, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()'))
          self.assertEqual(1, len(reports))
          self.assertEqual(reason, reports[0]['ended_by'])
          self.assertEqual(['comment ' + ending], [comment['message'] for comment in reports[0]['comments']])
          self.nvim.nvim.exec_lua("require('misc').TourStop()")
          completed.append(report_id)
          self.assertEqual(completed, [report['id'] for report in self.nvim.nvim.exec_lua(
            "return require('misc').GetTourComments()"
          )])
      self.assertEqual('first source\nsecond source\n', source.read_text())


  def test_comment_editor_wraps_and_saves_multiline_keyboard_input(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'multiline.lua'
      source.write_text('source remains unchanged\n')
      report_id = self.nvim.nvim.exec_lua(
        "return require('misc').ShowMe(..., {1, 1}, 'explanation', 'left')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      source_window = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
      source_buffer = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      paragraph = ' '.join(['A detailed paragraph about the selected code.'] * 3)
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input(paragraph + '\r\r')
      self.nvim.flush()
      editor = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
      editor_buffer = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.assertEqual('editor', self.nvim.nvim.request('nvim_win_get_config', editor)['relative'])
      self.assertTrue(self.nvim.nvim.request('nvim_win_get_option', editor, 'wrap'))
      self.assertTrue(self.nvim.nvim.request('nvim_win_get_option', editor, 'linebreak'))
      self.assertEqual([paragraph, '', ''], self.nvim.nvim.request(
        'nvim_buf_get_lines', editor_buffer, 0, -1, False
      ))

      self.nvim.nvim.input('Second paragraph.\x1b\r')
      self.nvim.flush()
      self.assertFalse(self.nvim.nvim.request('nvim_win_is_valid', editor))
      self.assertFalse(self.nvim.nvim.request('nvim_buf_is_valid', editor_buffer))
      self.assertEqual(source_window, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()'))
      self.assertEqual(['source remains unchanged'], self.nvim.nvim.request(
        'nvim_buf_get_lines', source_buffer, 0, -1, False
      ))
      self.assertFalse(self.nvim.nvim.request('nvim_buf_get_option', source_buffer, 'modified'))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
      self.assertEqual(paragraph + '\n\nSecond paragraph.', report['comments'][0]['message'])
      self.assertEqual('source remains unchanged\n', source.read_text())


  def test_closing_the_editor_or_presentation_discards_only_unsubmitted_text(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'cancel.lua'
      source.write_text('source\n')
      for closing in ('editor', 'presentation'):
        with self.subTest(closing=closing):
          origin = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()')
          report_id = self.nvim.nvim.exec_lua(
            "return require('misc').ShowMe(..., {1, 1}, 'explanation', 'left')", str(source)
          )
          self.nvim.nvim.command('wincmd h')
          self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('keep saved note')"))
          self.nvim.nvim.input('\\ta')
          self.nvim.nvim.input('unfinished draft\rwith a second line')
          self.nvim.flush()
          editor = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
          draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
          if closing == 'editor':
            self.nvim.nvim.request('nvim_win_close', editor, True)
            self.nvim.flush()
            open_report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
            self.assertEqual('in_progress', open_report['status'])
            self.assertEqual(['keep saved note'], [c['message'] for c in open_report['comments']])
          self.nvim.nvim.exec_lua("require('misc').TourStop()")
          self.nvim.flush()
          self.assertFalse(self.nvim.nvim.request('nvim_win_is_valid', editor))
          self.assertFalse(self.nvim.nvim.request('nvim_buf_is_valid', draft))
          self.assertEqual(origin, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()'))
          self.assertEqual('n', self.nvim.nvim.exec_lua('return vim.api.nvim_get_mode().mode'))
          report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
          self.assertEqual(['keep saved note'], [comment['message'] for comment in report['comments']])
      self.assertEqual('source\n', source.read_text())


  def test_comment_editor_resizes_without_losing_paragraphs(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'resize-comment.lua'
      source.write_text('source\n')
      report_id = self.nvim.nvim.exec_lua(
        "return require('misc').ShowMe(..., {1, 1}, 'explanation', 'left')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('first paragraph\rsecond paragraph')
      self.nvim.flush()
      editor = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.nvim.nvim.request('nvim_ui_try_resize', 50, 14)
      self.nvim.flush()
      config = self.nvim.nvim.request('nvim_win_get_config', editor)
      self.assertEqual(46, config['width'])
      self.assertGreater(config['height'], 0)
      self.assertLessEqual(config['height'], 10)
      self.nvim.nvim.request('nvim_ui_try_resize', 120, 30)
      self.nvim.flush()
      self.assertEqual(100, self.nvim.nvim.request('nvim_win_get_config', editor)['width'])
      self.assertEqual(['first paragraph', 'second paragraph'], self.nvim.nvim.request(
        'nvim_buf_get_lines', draft, 0, -1, False
      ))
      self.nvim.nvim.input('\x1b\r')
      self.nvim.flush()
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
      self.assertEqual('first paragraph\nsecond paragraph', report['comments'][0]['message'])


  def test_dismissing_a_background_comment_editor_preserves_caller_editing(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'background-comment.lua'
      source.write_text('source\n')
      origin = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()')
      caller_buffer = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.nvim.nvim.exec_lua(
        "require('misc').ShowMe(..., {1, 1}, 'explanation', 'left')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('unfinished comment')
      self.nvim.flush()
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.nvim.nvim.exec_lua('vim.api.nvim_set_current_tabpage(...)', origin)
      self.nvim.flush()
      self.nvim.nvim.input('ioutside draft')
      self.nvim.flush()
      self.assertEqual('i', self.nvim.nvim.exec_lua('return vim.api.nvim_get_mode().mode'))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      self.nvim.flush()
      self.assertEqual(origin, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_tabpage()'))
      self.assertEqual(caller_buffer, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()'))
      self.assertEqual('i', self.nvim.nvim.exec_lua('return vim.api.nvim_get_mode().mode'))
      self.assertEqual(['outside draft'], self.nvim.nvim.request(
        'nvim_buf_get_lines', caller_buffer, 0, -1, False
      ))
      self.assertFalse(self.nvim.nvim.request('nvim_buf_is_valid', draft))
      self.assertEqual([], self.nvim.nvim.exec_lua("return require('misc').GetTourComments()"))


  def test_second_annotation_request_reuses_the_existing_draft_and_its_target(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'two-panes.lua'
      source.write_text('left source\nright source\n')
      report_id = self.nvim.nvim.exec_lua(
        "return require('misc').ShowMe(..., {1, 1}, 'left', 'left')", str(source)
      )
      self.nvim.nvim.exec_lua(
        "require('misc').ShowMe(..., {2, 2}, 'right', 'right')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      panes = self.nvim.nvim.exec_lua('return vim.api.nvim_tabpage_list_wins(0)')
      right = max(panes, key=lambda win: self.nvim.nvim.request('nvim_win_get_position', win)[1])
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input('note for left')
      self.nvim.flush()
      editor = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()')
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.nvim.nvim.request('nvim_set_current_win', right)
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe()"))
      self.assertEqual(editor, self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_win()'))
      self.assertEqual(['note for left'], self.nvim.nvim.request('nvim_buf_get_lines', draft, 0, -1, False))
      self.nvim.nvim.input('\x1b\r')
      self.nvim.flush()
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      comment = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1].comments[1]", report_id)
      self.assertEqual('left', comment['side'])
      self.assertEqual({'first': 1, 'last': 1}, comment['range'])
      self.assertEqual('note for left', comment['message'])


  def test_one_range_comment_is_updated_across_panes_and_tour_scenes(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'one-comment.lua'
      source.write_text('source\n')
      scenes = [
        {
          'left': {'filename': str(source), 'range': [1, 1], 'message': 'left explanation'},
          'right': {'filename': str(source), 'range': [1, 1], 'message': 'right explanation'},
        },
        {'left': {'filename': str(source), 'range': [1, 1], 'message': 'another view'}},
      ]
      report_id = self.nvim.nvim.exec_lua("return require('misc').Tour(...)", scenes)
      self.nvim.nvim.command('wincmd h')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('old shared comment')"))
      self.nvim.nvim.command('wincmd l')
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('latest shared comment')"))
      self.nvim.flush()
      self.assertNotIn('old shared comment', self.nvim.text())
      self.assertEqual(2, self.nvim.text().count('latest shared comment'))

      self.nvim.nvim.exec_lua("require('misc').TourNext()")
      self.nvim.nvim.command('wincmd h')
      self.nvim.flush()
      self.assertIn('latest shared comment', self.nvim.text())
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe('edited from next scene')"))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
      self.assertEqual(1, len(report['comments']))
      comment = report['comments'][0]
      self.assertEqual('edited from next scene', comment['message'])
      self.assertEqual(str(source), comment['filename'])
      self.assertEqual({'first': 1, 'last': 1}, comment['range'])
      self.assertEqual(2, comment['step'])
      self.assertEqual('left', comment['side'])


  def test_ta_reopens_and_edits_one_multiline_comment_without_losing_saved_text(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      source = Path(directory) / 'edit-comment.lua'
      source.write_text('source\n')
      report_id = self.nvim.nvim.exec_lua(
        "return require('misc').ShowMe(..., {1, 1}, 'explanation', 'left')", str(source)
      )
      self.nvim.nvim.command('wincmd h')
      original = 'First paragraph.\n\nLast paragraph.'
      self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe(...)", original))
      self.nvim.nvim.input('\\ta')
      self.nvim.flush()
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.assertEqual(original.split('\n'), self.nvim.nvim.request('nvim_buf_get_lines', draft, 0, -1, False))
      self.nvim.nvim.input(' Edited.\x1b\r')
      self.nvim.flush()
      updated = original + ' Edited.'
      self.assertIn('Last paragraph. Edited.', self.nvim.text())

      self.nvim.nvim.input('\\ta')
      self.nvim.flush()
      draft = self.nvim.nvim.exec_lua('return vim.api.nvim_get_current_buf()')
      self.assertEqual(updated.split('\n'), self.nvim.nvim.request('nvim_buf_get_lines', draft, 0, -1, False))
      self.nvim.nvim.input(' discarded\x1bq')
      self.nvim.flush()
      self.assertNotIn('discarded', self.nvim.text())
      self.nvim.nvim.input('\\ta')
      self.nvim.nvim.input(' unfinished')
      self.nvim.flush()
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      report = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1]", report_id)
      self.assertEqual([updated], [comment['message'] for comment in report['comments']])
      self.assertEqual('source\n', source.read_text())


  def test_same_line_numbers_in_different_files_keep_independent_comments(self) -> None:
    with tempfile.TemporaryDirectory() as directory:
      left = Path(directory) / 'left.lua'
      right = Path(directory) / 'right.lua'
      left.write_text('left source\n')
      right.write_text('right source\n')
      report_id = self.nvim.nvim.exec_lua(
        "return require('misc').ShowMe(..., {1, 1}, 'left', 'left')", str(left)
      )
      self.nvim.nvim.exec_lua("require('misc').ShowMe(..., {1, 1}, 'right', 'right')", str(right))
      for command, message in (
        ('wincmd h', 'left note'), ('wincmd l', 'right note'), ('wincmd h', 'revised left note'),
      ):
        self.nvim.nvim.command(command)
        self.assertTrue(self.nvim.nvim.exec_lua("return require('misc').AnnotateShowMe(...)", message))
      self.nvim.nvim.exec_lua("require('misc').TourStop()")
      comments = self.nvim.nvim.exec_lua("return require('misc').GetTourComments(...)[1].comments", report_id)
      self.assertEqual([str(left), str(right)], [comment['filename'] for comment in comments])
      self.assertEqual(['revised left note', 'right note'], [comment['message'] for comment in comments])


class PersistedFeedbackTest(unittest.TestCase):
  def setUp(self) -> None:
    state = tempfile.TemporaryDirectory()
    self.addCleanup(state.cleanup)
    self.state_home = state.name
    source_dir = tempfile.TemporaryDirectory()
    self.addCleanup(source_dir.cleanup)
    self.source = Path(source_dir.name) / 'source.lua'
    self.source.write_text('first\nsecond\n')

  def attach(self) -> AttachedNvim:
    instance = AttachedNvim(self.state_home)
    self.addCleanup(instance.close)
    return instance

  def start_tour_with_comment(self, instance: AttachedNvim, message: str) -> str:
    report_id = instance.nvim.exec_lua(
      "return require('misc').Tour({{left = {filename = ..., range = {1, 1}, message = 'look'}}})",
      str(self.source),
    )
    instance.flush()
    saved = instance.nvim.exec_lua(
      """
      local windows = vim.api.nvim_tabpage_list_wins(0)
      table.sort(windows, function(a, b)
        return vim.api.nvim_win_get_position(a)[2] < vim.api.nvim_win_get_position(b)[2]
      end)
      vim.api.nvim_set_current_win(windows[1])
      return require('misc').AnnotateShowMe(...)
      """,
      message,
    )
    self.assertTrue(saved)
    return report_id

  def reports(self, instance: AttachedNvim, report_id: str | None = None):
    if report_id is None:
      return instance.nvim.exec_lua("return require('misc').GetTourComments()")
    return instance.nvim.exec_lua("return require('misc').GetTourComments(...)", report_id)

  def acknowledge(self, instance: AttachedNvim, report_id: str):
    return instance.nvim.exec_lua("return require('misc').AcknowledgeTourComments(...)", report_id)

  def test_comment_saved_in_open_tour_is_returned_before_the_tour_ends(self) -> None:
    nvim = self.attach()
    report_id = self.start_tour_with_comment(nvim, 'early comment')

    reports = self.reports(nvim)
    self.assertEqual([report_id], [report['id'] for report in reports])
    self.assertEqual('in_progress', reports[0]['status'])
    self.assertEqual('tour', reports[0]['kind'])
    self.assertEqual(['early comment'], [c['message'] for c in reports[0]['comments']])
    self.assertEqual(str(self.source), reports[0]['comments'][0]['filename'])

    nvim.nvim.exec_lua("require('misc').TourStop()")
    reports = self.reports(nvim, report_id)
    self.assertEqual('completed', reports[0]['status'])
    self.assertEqual('stopped', reports[0]['ended_by'])

  def test_report_is_stored_as_json_under_the_state_directory(self) -> None:
    nvim = self.attach()
    report_id = self.start_tour_with_comment(nvim, 'on disk')

    directory = Path(self.state_home) / 'nvim' / 'misc' / 'reports'
    self.assertEqual([f'{report_id}.json'], sorted(p.name for p in directory.iterdir()))
    stored = json.loads((directory / f'{report_id}.json').read_text())
    self.assertEqual(report_id, stored['id'])
    self.assertEqual('in_progress', stored['status'])
    self.assertEqual(['on disk'], [c['message'] for c in stored['comments']])

  def test_report_without_comments_is_not_pending(self) -> None:
    nvim = self.attach()
    nvim.nvim.exec_lua(
      "return require('misc').Tour({{left = {filename = ..., range = {1, 1}, message = 'look'}}})",
      str(self.source),
    )
    self.assertEqual([], self.reports(nvim))

  def test_report_survives_kill_and_can_be_acknowledged_from_a_fresh_nvim(self) -> None:
    first = self.attach()
    report_id = self.start_tour_with_comment(first, 'survives crash')
    first.nvim.exec_lua("require('misc').TourStop()")
    first.kill()

    second = self.attach()
    reports = self.reports(second)
    self.assertEqual([report_id], [report['id'] for report in reports])
    self.assertEqual('completed', reports[0]['status'])
    self.assertEqual(['survives crash'], [c['message'] for c in reports[0]['comments']])
    self.assertTrue(self.acknowledge(second, report_id))
    self.assertEqual([], self.reports(second))

  def test_open_tour_report_of_a_killed_nvim_is_returned_in_progress(self) -> None:
    first = self.attach()
    report_id = self.start_tour_with_comment(first, 'never finished')
    first.kill()

    second = self.attach()
    reports = self.reports(second)
    self.assertEqual([report_id], [report['id'] for report in reports])
    self.assertEqual('in_progress', reports[0]['status'])

  def test_acknowledged_report_is_no_longer_pending_in_any_instance(self) -> None:
    first = self.attach()
    report_id = self.start_tour_with_comment(first, 'handled')
    first.nvim.exec_lua("require('misc').TourStop()")
    second = self.attach()

    self.assertEqual([report_id], [r['id'] for r in self.reports(second)])
    self.assertTrue(self.acknowledge(second, report_id))
    self.assertTrue(self.acknowledge(second, report_id))
    self.assertEqual([], self.reports(first))
    self.assertEqual([], self.reports(second))
    self.assertEqual([], self.reports(second, report_id))

  def test_open_report_cannot_be_acknowledged_and_unknown_ids_are_rejected(self) -> None:
    nvim = self.attach()
    report_id = self.start_tour_with_comment(nvim, 'still open')
    self.assertFalse(self.acknowledge(nvim, report_id))
    self.assertFalse(self.acknowledge(nvim, 'tour-0-0-0'))
    self.assertFalse(self.acknowledge(nvim, '../escape'))
    self.assertEqual([report_id], [r['id'] for r in self.reports(nvim)])

  def test_no_temporary_files_are_left_behind(self) -> None:
    nvim = self.attach()
    report_id = self.start_tour_with_comment(nvim, 'atomic')
    nvim.nvim.exec_lua("require('misc').TourStop()")
    self.acknowledge(nvim, report_id)
    directory = Path(self.state_home) / 'nvim' / 'misc' / 'reports'
    self.assertEqual([f'{report_id}.json'], [p.name for p in directory.iterdir()])


if __name__ == '__main__':
  unittest.main()
