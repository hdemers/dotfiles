#!/usr/bin/env python3
"""
Optimiseur de voyage — template générique.
Lit donnees/ + params.json, génère toutes les combinaisons valides,
calcule le coût total et le score pondéré, affiche les meilleures options.

Usage:
    uv run optimiser.py [top_n]
"""
import json
import sys
from pathlib import Path

DONNEES = Path(__file__).parent / "donnees"


def charger():
    with open(DONNEES / "destinations.json") as f:
        destinations = json.load(f)
    with open(DONNEES / "vols.json") as f:
        vols = json.load(f)
    with open(DONNEES / "hebergements.json") as f:
        hebergements = json.load(f)
    with open(DONNEES / "autos.json") as f:
        autos = json.load(f)
    with open(DONNEES / "params.json") as f:
        params = json.load(f)
    return destinations, vols, hebergements, autos, params


def generer_combinaisons(destinations, vols, hebergements, autos, params):
    nb_nuits = params["nb_nuits"]
    nb_personnes = params["nb_personnes"]
    filtres = params["filtres"]

    heberg_par_dest = {}
    for h in hebergements:
        heberg_par_dest.setdefault(h["destination"], []).append(h)

    autos_par_aeroport = {}
    for a in autos:
        autos_par_aeroport.setdefault(a["aeroport"], []).append(a)

    combos = []

    for vol in vols:
        if vol.get("escales", 0) > filtres["escales_max"]:
            continue

        aeroport = vol["aeroport_arrivee"]
        autos_dispo = autos_par_aeroport.get(aeroport, [])
        if not autos_dispo:
            continue

        cout_vol = vol["prix_par_personne"] * nb_personnes

        for dest in destinations:
            if aeroport not in dest["aeroports"]:
                continue

            for heberg in heberg_par_dest.get(dest["nom"], []):
                note = heberg.get("note")
                nb_avis = heberg.get("nb_avis", 0) or 0
                if note is None:
                    continue
                if note < filtres["note_min"]:
                    continue
                if nb_avis < filtres["nb_avis_min"]:
                    continue

                cout_heberg = heberg["prix_nuit_cad"] * nb_nuits

                for auto in autos_dispo:
                    cout_auto = auto["prix_jour_cad"] * nb_nuits
                    cout_total = cout_vol + cout_heberg + cout_auto

                    combos.append({
                        "vol": vol,
                        "destination": dest,
                        "hebergement": heberg,
                        "auto": auto,
                        "cout_vol": cout_vol,
                        "cout_heberg": cout_heberg,
                        "cout_auto": cout_auto,
                        "cout_total": cout_total,
                    })

    return combos


def scorer(combos, params):
    if not combos:
        return []

    poids = params["poids"]
    budget = params["budget_total"]

    couts = [c["cout_total"] for c in combos]
    cout_min, cout_max = min(couts), max(couts)
    cout_range = cout_max - cout_min or 1

    notes = [c["hebergement"]["note"] for c in combos]
    note_min_obs, note_max_obs = min(notes), max(notes)
    note_range = note_max_obs - note_min_obs or 1

    durees = [c["vol"].get("duree_heures") or 0 for c in combos]
    duree_min, duree_max = min(durees), max(durees)
    duree_range = duree_max - duree_min or 1

    resultats = []
    for c in combos:
        s_cout  = (cout_max - c["cout_total"]) / cout_range
        s_note  = (c["hebergement"]["note"] - note_min_obs) / note_range
        s_duree = (duree_max - (c["vol"].get("duree_heures") or 0)) / duree_range
        s_esc   = 1.0 if c["vol"].get("escales", 0) == 0 else 0.0

        score = (
            poids["cout"]      * s_cout
            + poids["note"]    * s_note
            + poids["duree_vol"] * s_duree
            + poids["escales"] * s_esc
        )

        c["score"] = round(score, 4)
        c["dans_budget"] = c["cout_total"] <= budget
        resultats.append(c)

    return sorted(resultats, key=lambda x: x["score"], reverse=True)


def afficher(resultats, params, top_n=10):
    devise = params.get("devise", "$")
    nb_nuits = params["nb_nuits"]
    budget_ok  = [r for r in resultats if r["dans_budget"]]
    hors_budget = [r for r in resultats if not r["dans_budget"]]

    def ligne(r, rang):
        v = r["vol"]
        h = r["hebergement"]
        a = r["auto"]
        d = r["destination"]
        print(f"\n{'─'*70}")
        print(f"#{rang}  Score: {r['score']:.4f}   Coût total: {devise}{r['cout_total']:,.0f}"
              f"{'  ✓ budget' if r['dans_budget'] else '  ✗ hors budget'}")
        print(f"    Destination : {d['nom']}  ({d['region']})")
        print(f"    Vol         : {v['date_depart']} → {v['date_retour']}  "
              f"{v.get('compagnie', '?')}  {v['aeroport_arrivee']}  "
              f"{v['escales']} escale(s)  {v.get('duree_heures', '?')}h  "
              f"{devise}{v['prix_par_personne']:,}/pers  (×{params['nb_personnes']} = {devise}{r['cout_vol']:,})")
        print(f"    Hébergement : {h['titre'][:55]}  "
              f"★{h['note']} ({h.get('nb_avis', '?')} avis)  "
              f"{devise}{h['prix_nuit_cad']}/nuit  (×{nb_nuits} = {devise}{r['cout_heberg']:,})")
        print(f"    Transport   : {a.get('exemple_vehicule', a['categorie'])} ({a['categorie']})  "
              f"{a['fournisseur']}  {devise}{a['prix_jour_cad']}/j  "
              f"(×{nb_nuits} = {devise}{r['cout_auto']:,})")
        if h.get("url"):
            print(f"    Airbnb      : {h['url']}")

    print(f"\n{'='*70}")
    print(f"  RÉSULTATS — TOP {top_n} dans le budget")
    print(f"{'='*70}")
    print(f"  Combinaisons dans le budget : {len(budget_ok)}")
    print(f"  Combinaisons hors budget    : {len(hors_budget)}")
    print(f"  Total                       : {len(resultats)}")

    for i, r in enumerate(budget_ok[:top_n], 1):
        ligne(r, i)

    if not budget_ok:
        print("\nAucune combinaison dans le budget. Top 5 hors budget :")
        for i, r in enumerate(hors_budget[:5], 1):
            ligne(r, i)

    print(f"\n{'='*70}\n")


def main():
    top_n = int(sys.argv[1]) if len(sys.argv) > 1 else 10
    destinations, vols, hebergements, autos, params = charger()

    print(f"Données chargées : {len(destinations)} destinations, {len(vols)} vols, "
          f"{len(hebergements)} hébergements, {len(autos)} transports")

    combos = generer_combinaisons(destinations, vols, hebergements, autos, params)
    print(f"Combinaisons valides : {len(combos)}")

    resultats = scorer(combos, params)
    afficher(resultats, params, top_n)


if __name__ == "__main__":
    main()
