# Atlas des civilisations — v2.1.0

Atlas historique interactif (5000 av. J.-C. → 1900) : carte et frise synchronisées, territoires, lieux, événements, filiations, tutelles.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `index.html` | l'application (page unique) |
| `config.js` | URL et clé publique Supabase — à renseigner |
| `data/atlas.json` | jeu de données : initialisation de la base et copie de secours |
| `data/enrichissement_v2.1.0.json` | civilisations supplémentaires et emprises datées, à appliquer depuis l'onglet *Données* |
| `data/geo/base.json` | fond de carte 1:50 000 000 (vue d'ensemble) |
| `data/geo/t/*.json` | 464 tuiles 10° × 10° au 1:10 000 000, chargées au zoom |
| `data/geo/relief/` | relief ombré : image d'ensemble + 69 tuiles 30° × 30°, chargées au zoom |
| `supabase/schema_v2.0.0.sql` | tables, règles d'accès (RLS) et fonctions |
| `tools/build_geo.py` | régénère `data/geo` (traits de côte, lacs, fleuves) depuis Natural Earth |
| `tools/build_relief_v2.1.0.py` | régénère `data/geo/relief` |
| `tools/build_enrich_v2.1.0.py`, `tools/enrich/` | régénèrent le fichier d'enrichissement |
| `.nojekyll` | sert les fichiers tels quels sur GitHub Pages |

## Fonctionnement

GitHub Pages ne sert que des fichiers statiques : les comptes et l'enregistrement reposent sur **Supabase** (offre gratuite suffisante). Les données publiées sont lues automatiquement par tous les visiteurs.

| Rôle | Obtention | Droits |
|---|---|---|
| Visiteur | sans compte | consultation |
| Contributeur | création libre de compte (e-mail confirmé) | modifie en brouillon, envoie des propositions |
| Éditeur | attribué par un administrateur | publie directement, valide ou refuse les propositions |
| Administrateur | attribué en SQL (le premier) puis dans l'application | idem + rôles + rechargement de la base |

Toute écriture passe par des fonctions serveur qui vérifient le rôle ; la clé `anon` présente dans `config.js` est publique par conception et ne permet que la lecture et le dépôt d'une proposition à son propre nom. Chaque version remplacée ou supprimée est conservée dans la table `item_history`.

Si `config.js` est laissé vide, l'atlas fonctionne en **mode fichier** : lecture de `data/atlas.json`, modifications conservées dans le navigateur, export JSON à recommiter dans le dépôt.

## Mise en service

1. **Supabase** — créer un projet sur supabase.com, puis *SQL Editor* › coller et exécuter `supabase/schema_v2.0.0.sql`.
2. **Authentification** — *Authentication › URL Configuration* :
   - *Site URL* : `https://<compte>.github.io/<depot>/`
   - *Redirect URLs* : la même adresse (liens de confirmation et de réinitialisation du mot de passe).
   - Laisser *Confirm email* actif (*Authentication › Providers › Email*).
3. **Configuration** — *Project Settings › API* : copier *Project URL* et la clé *anon public* dans `config.js`. Ne jamais y mettre la clé `service_role`.
4. **Publication** — pousser le dépôt sur GitHub, puis *Settings › Pages* › *Deploy from a branch* › `main` / racine.
5. **Premier administrateur** — créer son compte depuis le site (bouton *Se connecter* › *Créer un compte*), confirmer l'e-mail, puis dans *SQL Editor* :
   ```sql
   update public.profiles set role = 'admin'
   where id = (select id from auth.users where email = 'votre.adresse@exemple.fr');
   ```
   Recharger la page.
6. **Données** — onglet *Données* › *Initialiser la base depuis data/atlas.json*.

Les rôles des autres comptes se gèrent ensuite depuis *Données › Comptes et rôles…*.

## Mise à jour depuis la v2.0.0

1. Copier par-dessus le dépôt le contenu de l'archive v2.1.0 (seuls les fichiers modifiés ou nouveaux y figurent ; `config.js`, `data/atlas.json` et le schéma SQL sont inchangés). Commit, push.
2. Sur le site, connecté en éditeur ou administrateur : *Données › Enrichir l'atlas (v2.1.0)…*.
3. Lire le récapitulatif, puis *Appliquer*. La publication part en plusieurs lots ; attendre « publié » en haut à droite.
4. Facultatif : *Données › Compléter les images* (va chercher une image pour chaque fiche munie d'un lien Wikipédia).
5. *Données › Exporter (.json)* et remplacer `data/atlas.json` dans le dépôt, pour que la copie de secours suive.

### Règle de préservation de l'enrichissement

L'enrichissement raisonne civilisation par civilisation, sur la base publiée au moment où on le lance :

- **civilisation absente** → ajoutée avec ses emprises et sa capitale ;
- **tracés tous identiques au fonds d'origine** (reconnus par empreinte, rien d'ajouté ni de supprimé) → remplacés par les emprises datées ;
- **au moins un tracé retouché, ajouté ou supprimé** → conservés tels quels ; une case « Remplacer » permet de forcer, au cas par cas ;
- **civilisation que vous avez supprimée** → ignorée ;
- **emprises déjà présentes à l'identique** → rien à faire, l'opération peut être relancée sans effet.

Les descriptions, dates, couleurs, événements et lieux existants ne sont jamais modifiés. L'ensemble s'annule avec Ctrl+Z tant que la page n'est pas rechargée ; au-delà, la table `item_history` conserve chaque version remplacée.

## Exploitation

- **Copie de secours** : *Données › Exporter (.json)* puis remplacer `data/atlas.json` dans le dépôt. Ce fichier est affiché, en lecture seule, si la base est injoignable.
- **Restauration d'un élément** : consulter `item_history` (colonne `old_data`) dans Supabase.
- **Envoi des e-mails** : le service d'envoi intégré à Supabase est limité à quelques messages par heure ; pour un usage public, configurer un SMTP (*Project Settings › Authentication › SMTP Settings*).
- **Mise en veille** : un projet gratuit inactif une semaine est suspendu ; il se réactive depuis le tableau de bord. Pendant ce temps, le site affiche la copie de `data/atlas.json`.
- **Test local** : `python3 -m http.server` à la racine du dépôt, puis http://localhost:8000 (l'ouverture directe du fichier ne permet pas de charger les données).

## Interface

- **Fiche › Description** : présentation en lecture (image, texte, repères, relations, lieux, emprises), seule vue offerte aux visiteurs.
- **Fiche › Technique** (comptes autorisés) : toutes les propriétés modifiables sur place, image comprise, et les listes de territoires, tutelles, filiations, événements et lieux avec leurs actions.
- Sans sélection, la fiche liste les civilisations présentes à l'année du curseur.
- Les images sont de simples adresses `https://` (Wikimedia Commons de préférence) ; rien n'est stocké dans la base.

## Sources et licences

- **Fond de carte et relief** : Natural Earth, domaine public.
- **Emprises de l'enrichissement v2.1.0** : [historical-basemaps](https://github.com/aourednik/historical-basemaps), A. Ourednik, **GPL-3.0**. Le fichier `data/enrichissement_v2.1.0.json`, et les emprises qui en sont issues dans la base, sont donc diffusés sous cette licence, avec mention de la source (faite dans l'onglet *Données*). Les tracés sont des instantanés de précision « approximative » selon leur auteur, simplifiés à ≈ 2,5 km ; ils restent corrigeables comme les autres.

## Fond de carte

Natural Earth (domaine public) : 1:50 000 000 en vue d'ensemble, tuiles 1:10 000 000 sous 48° de largeur de vue, relief ombré (tuiles détaillées sous 110°). Les réservoirs modernes sont retirés ; la mer d'Aral et le lac Tchad sont dans leur emprise historique. Régénération :

```bash
pip install shapely
# télécharger dans ./ne les GeoJSON ne_50m_* et ne_10m_* : land, lakes, lakes_historic, rivers_lake_centerlines
# (github.com/nvkelso/natural-earth-vector, dossier geojson)
python3 tools/build_geo.py ./ne ./data/geo
# relief : shadedrelief.jpg (10800 × 5400) se trouve dans le paquet PyPI basemap-data
pip install scipy pillow numpy
python3 tools/build_relief_v2.1.0.py shadedrelief.jpg ./ne/ne_50m_land.geojson ./ne/ne_50m_lakes.geojson ./data/geo/relief
```

Enrichissement (à partir des GeoJSON de historical-basemaps, dossier `geojson`) :

```bash
python3 tools/build_enrich_v2.1.0.py ./historical-basemaps/geojson tools/enrich/correspondances_v2.1.0.json emprises.json
node tools/enrich/build_patch_v2.1.0.js emprises.json data/enrichissement_v2.1.0.json
```

## Historique

- **2.1.0** — relief ombré ; fiche Description et onglet Technique (édition sur place), images ; onglet Éléments retiré ; enrichissement non destructif (32 civilisations, 577 emprises datées) ; publication par lots.
- **2.0.0** — base partagée Supabase avec comptes, rôles et validation des propositions ; chargement automatique des données ; fond de carte multi-échelle 1:50M / 1:10M ; zoom ×5 ; coordonnées au millième de degré.
