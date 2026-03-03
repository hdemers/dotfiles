---
name: vacances
description: >
  Planificateur de voyage interactif. Collecte destinations, vols, hébergements
  et transport, optimise les combinaisons et génère un explorer.html interactif.
  Déclencher quand l'utilisateur veut planifier un voyage de vacances.
tools:
---

## Objectif

Planifier un voyage en collectant et optimisant toutes les options : destinations,
vols, hébergements et transport. Résultat final : un fichier `explorer.html`
autonome (sans serveur) pour explorer et comparer les options visuellement.

## Étape 1 — Informations initiales

Demander à l'utilisateur (avec `AskUserQuestion` ou en posant les questions) :

1. **Type de voyage** : Quel type de voyage ? Choix : **vélo**, **ski**, **tourisme**
2. **Destination** : Où voulez-vous aller en vacances ? (pays, région)
3. **Budget** : Quel est votre budget par personne ? (montant + devise)
4. **Voyageurs** : Combien de personnes voyageront ?
5. **Durée** : Combien de jours / nuits ?
6. **Dates** : Flexibles ou fixes ? Si flexibles, quelle période ?
7. **Aéroport de départ** : Quel(s) aéroport(s) ?
8. **Transport sur place** : Location d'auto ? Train ? Autre ?
9. **Hébergement** : Airbnb ? Hôtel ? Type préféré ? Budget nuit max ?
10. **Contraintes** : Cuisinette requise ? Annulation flexible ? Animaux ?

### Questions supplémentaires selon le type

**Vélo** :

- Niveau de difficulté : débutant / intermédiaire / difficile / expert ?
- Type de vélo : gravel, VTT, route ?
- Remontées mécaniques souhaitées ?
- Auto assez grande pour accepter vélos ?

**Ski** : _(champs spécifiques à définir plus tard)_

## Étape 2 — Création du projet

1. Dans le répertoire actuel:
   1. Créer `donnees/` avec les fichiers JSON (voir schémas ci-dessous)
   2. Créer `params.json` (voir schéma ci-dessous)
   3. Copier l'optimiseur :
      ```bash
      cp ~/.claude/skills/vacances/templates/optimiser.py .
      ```
2. Copier le template :
   ```bash
   cp ~/.claude/skills/vacances/explorer-template.html \
      ~/Dropbox/Public/<NomDestination>-<Année>/explorer.html
   ```

## Étape 3 — Collecte des données

**CRITIQUE : lancer T1, T2, T3 et T4 en parallèle via des subagents.**
Chaque tâche est indépendante et peut s'exécuter simultanément pour réduire le temps
de collecte. Utiliser l'Agent tool avec `run_in_background: true` pour T1, T2, T3, T4,
puis attendre leur complétion avant de passer à l'étape 4.

### T1 — Destinations candidates *(subagent)*

- Identifier 8–15 destinations dans la région cible
- Viser la variété (régions, distances depuis l'aéroport, types de terrain)
- Collecter tous les champs du schéma `destinations.json`
- **Outils** : WebSearch, WebFetch, Browser automation
- Sauvegarder dans `donnees/destinations.json`

### T2 — Vols *(subagent)*

- Via **Google Flights MCP** : chercher toutes les semaines dans la période cible
- Chercher aller-retour (durée = nb_nuits)
- Tester tous les aéroports d'arrivée pertinents
- Collecter tous les champs du schéma `vols.json`
- Sauvegarder dans `donnees/vols.json`

### T3 — Hébergements *(subagent)*

- Via **Airbnb MCP** : pour chaque destination, chercher 15–25 options
- Appliquer filtre budget nuit max (critère `prix_nuit_max` de params.json)
- **Collecter large** — la sélection visuelle (beauté, vue, charme) est faite
  par l'utilisateur dans explorer.html
- Collecter tous les champs du schéma `hebergements.json`
- Sauvegarder dans `donnees/hebergements.json`
- Note : T3 dépend des destinations trouvées par T1 — attendre T1 si T3 nécessite
  la liste complète des destinations avant de démarrer

### T4 — Transport local *(subagent)*

- Via **Browser automation** (`mcp__claude-in-chrome__*`) ou WebSearch
- Chercher options selon le type de transport (auto, train pass, etc.)
- Si location d'auto : chercher à chaque aéroport d'arrivée
- Collecter tous les champs du schéma `autos.json`
- Sauvegarder dans `donnees/autos.json`

## Étape 4 — Base de données et optimisation

1. Vérifier la cohérence des données (aéroports identiques entre vols/autos/destinations)
2. Lancer l'optimiseur :
   ```bash
   uv run optimiser.py
   ```
3. Analyser les résultats, itérer sur `params.json` si nécessaire
4. Produire un rapport `rapport.md` avec les 3 meilleures options

## Étape 5 — Explorer interactif

1. Mettre à jour `VOYAGE_CONFIG` dans `explorer.html` :
   - `titre` : nom du voyage (ex. "Voyage Japon 2026")
   - `emoji` : emoji représentatif (ex. "🗾")
   - `activite` : type de voyage (ex. "Culture & Gastronomie")
   - `type` : `"velo"` | `"ski"` | `"tourisme"` — contrôle les sections spécifiques
   - `devise` : devise (ex. "CA$")
   - `nb_nuits` : durée en nuits
   - `nb_personnes` : nombre de voyageurs
   - `aeroport_depart` : code IATA de l'aéroport de départ

2. Injecter les données JSON dans `explorer.html` via script Python :

   ```python
   import re, json
   from pathlib import Path

   html = Path('explorer.html').read_text()
   for nom_const, fichier in [
       ('DESTINATIONS', 'donnees/destinations.json'),
       ('VOLS_RAW',     'donnees/vols.json'),
       ('HEBERGEMENTS', 'donnees/hebergements.json'),
       ('AUTOS',        'donnees/autos.json'),
   ]:
       data = json.loads(Path(fichier).read_text())
       json_str = json.dumps(data, ensure_ascii=False)
       html = re.sub(
           rf'const {nom_const}\s*=\s*\[.*?\];',
           f'const {nom_const} = {json_str};',
           html, flags=re.DOTALL
       )
   # IMAGES (objet)
   images = json.loads(Path('donnees/images.json').read_text())
   html = re.sub(
       r'const IMAGES\s*=\s*\{[^;]*\};',
       f'const IMAGES = {json.dumps(images, ensure_ascii=False)};',
       html
   )
   Path('explorer.html').write_text(html)
   ```

3. Scraper les images Airbnb (si nécessaire) via `scraper_images.py`
4. Ouvrir dans le navigateur pour sélection visuelle par l'utilisateur

---

## Schémas JSON

### destinations.json — tableau d'objets

```json
{
  "nom": "Kyoto",
  "region": "Kansai",
  "aeroports": ["KIX", "ITM"],
  "distance_aeroport_km": { "KIX": 75, "ITM": 40 },
  "coords": [35.0116, 135.7681],
  "description": "Ancienne capitale impériale, temples et jardins zen.",
  "point_fort": "Plus de 1600 temples et sanctuaires, quartiers historiques préservés.",
  "activites": ["Temples & sanctuaires", "Gastronomie", "Vélo", "Randonnée"],
  "stats": [
    { "icon": "landscape", "valeur": "800 m (mont Hiei)" },
    { "icon": "route", "valeur": "75 km pistes cyclables" }
  ],
  "liens": {
    "site officiel": "https://kyoto.travel/en",
    "office du tourisme": "https://kyoto.travel/en"
  },
  "notes": "Très fréquenté en avril (cerisiers) et novembre (érables)."
}
```

**Champs obligatoires** : `nom`, `region`, `aeroports`, `distance_aeroport_km`, `coords`
**Champs optionnels** : `description`, `point_fort`, `activites`, `stats`, `liens`, `notes`

#### Champs supplémentaires — type `velo`

```json
{
  "remontee_nom": "First Gondola",
  "remontee_accepte_velos": true,
  "remontee_prix_chf": 45,
  "remontee_mois_ouverts": [6, 7, 8, 9],
  "difficulte_trails": "tous niveaux",
  "altitude_village_m": 1034,
  "altitude_sommet_m": 2168,
  "trails_km": 150,
  "gravel_routes": [
    {
      "nom": "Gravel Eiger Loop",
      "distance_km": 45,
      "denivele_pos_m": 1100,
      "type": "gravel",
      "niveau": "intermédiaire",
      "description": "Boucle autour de l'Eiger"
    }
  ]
}
```

`niveau` accepte : `facile` | `intermédiaire` | `difficile` | `expert`

---

### vols.json — tableau d'objets

```json
{
  "aeroport_arrivee": "KIX",
  "date_depart": "2026-07-04",
  "date_retour": "2026-07-18",
  "prix_par_personne": 1400,
  "compagnie": "Air Canada",
  "duree_heures": 13.5,
  "escales": 1,
  "heure_depart": "14:00",
  "heure_arrivee": "17:30",
  "url": "https://www.google.com/flights/..."
}
```

**Champs obligatoires** : `aeroport_arrivee`, `date_depart`, `date_retour`, `prix_par_personne`, `compagnie`, `escales`
**Champs optionnels** : `duree_heures`, `heure_depart`, `heure_arrivee`, `url`

---

### hebergements.json — tableau d'objets

```json
{
  "destination": "Kyoto",
  "titre": "Machiya traditionnelle avec jardin",
  "airbnb_id": "12345678",
  "url": "https://www.airbnb.ca/rooms/12345678",
  "prix_nuit_cad": 180,
  "note": 4.9,
  "nb_avis": 87,
  "nb_chambres": 2,
  "cuisinette": true,
  "reservation_instantanee": true,
  "annulation_jours": 30,
  "stationnement": false,
  "notes": "Vue sur jardin zen, 5 min métro"
}
```

**Champs obligatoires** : `destination`, `titre`, `airbnb_id`, `url`, `prix_nuit_cad`
**Champs optionnels** : `note`, `nb_avis`, `nb_chambres`, `cuisinette`, `reservation_instantanee`, `annulation_jours`, `stationnement`, `notes`

#### Champs supplémentaires — type `velo`

```json
{
  "rangement_velos": true,
  "distance_remontee_km": 0.5
}
```

---

### autos.json — tableau d'objets (ou transport local générique)

```json
{
  "aeroport": "KIX",
  "fournisseur": "Europcar",
  "categorie": "Compact",
  "exemple_vehicule": "Toyota Corolla",
  "prix_jour_cad": 75,
  "km_illimite": true,
  "assurance_incluse": false,
  "notes": "Coffre 2 valises",
  "url": "https://www.europcar.com/..."
}
```

**Champs obligatoires** : `aeroport`, `fournisseur`, `categorie`, `prix_jour_cad`
**Champs optionnels** : `exemple_vehicule`, `km_illimite`, `assurance_incluse`, `notes`, `url`

#### Champs supplémentaires — type `velo`

```json
{
  "capacite_velo": 2
}
```

---

### donnees/images.json — objet (clé = airbnb_id)

```json
{
  "12345678": "https://a0.muscache.com/im/pictures/...",
  "87654321": "https://a0.muscache.com/im/pictures/..."
}
```

---

### params.json — objet de configuration

```json
{
  "nb_personnes": 2,
  "nb_nuits": 14,
  "devise": "CA$",
  "budget_total": 10000,
  "prix_nuit_max": 300,

  "poids": {
    "cout": 0.5,
    "note": 0.3,
    "duree_vol": 0.1,
    "escales": 0.1
  },

  "filtres": {
    "note_min": 4.0,
    "nb_avis_min": 3,
    "escales_max": 1
  }
}
```

---

## Fichiers template disponibles

| Fichier                                            | Description                    |
| -------------------------------------------------- | ------------------------------ |
| `~/.claude/skills/vacances/explorer-template.html` | Interface interactive autonome |
| `~/.claude/skills/vacances/templates/optimiser.py` | Optimiseur à adapter           |

## Décisions et bonnes pratiques

- **Collecter large** : mieux avoir trop de données que pas assez ; l'utilisateur
  filtrera visuellement dans explorer.html
- **Ne jamais faire de réservations** : uniquement collecter et présenter les options
- **Aéroports** : tester tous les aéroports raisonnables depuis la ville de départ
- **Hébergements** : Airbnb MCP cherche par destination — viser 15–25 par lieu
- **Images Airbnb** : les `og:image` sont optionnelles ; l'interface a un fallback emoji
- **params.json** : seul fichier à modifier pour itérer l'optimisation sans retoucher le code
