# Atlas des civilisations — v2.3.1

Atlas historique interactif (5000 av. J.-C. → 1900) : carte et frise synchronisées, territoires, lieux, événements, filiations, tutelles.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `index.html` | l'application (page unique) |
| `config.js` | URL et clé publique Supabase — à renseigner |
| `data/atlas.json` | jeu de données : initialisation de la base et copie de secours |
| `data/geo/base.json` | fond de carte 1:50 000 000 (vue d'ensemble) |
| `data/geo/t/*.json` | 464 tuiles 10° × 10° au 1:10 000 000, chargées au zoom |
| `data/geo/relief/` | relief ombré : image d'ensemble + 69 tuiles 30° × 30°, chargées au zoom |
| `supabase/schema_v2.0.0.sql` | tables, règles d'accès (RLS) et fonctions |
| `tools/build_geo.py` | régénère `data/geo` (traits de côte, lacs, fleuves) depuis Natural Earth |
| `tools/build_relief_v2.1.0.py` | régénère `data/geo/relief` |
| `tools/build_enrich_v2.1.0.py`, `tools/enrich/` | ont produit l'enrichissement v2.1.0 (conservés pour la traçabilité de la source GPL) |
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

## Données

L'enrichissement v2.1.0 (civilisations supplémentaires, emprises datées) est désormais intégré à la base ; l'application ne propose plus d'import. Le fichier `data/enrichissement_v2.1.0.json` peut être retiré du dépôt, **après** avoir déposé un export à jour (*Données › Exporter (.json)*) à la place de `data/atlas.json`, qui sert de copie de secours et d'initialisation.

## Interface

- **Fiche › Description** : présentation en lecture (image, texte, repères, relations, lieux, emprises), seule vue offerte aux visiteurs.
- **Fiche › Technique** (comptes autorisés) : toutes les propriétés modifiables sur place, image comprise, et les listes de territoires, tutelles, filiations, événements et lieux avec leurs actions.
- Sans sélection, la fiche liste les civilisations présentes à l'année du curseur.
- **Panneau latéral et frise** repliables (bouton *Panneau*, flèche ▾ de la frise, touches **P**, **F**, **C** pour la carte seule) et redimensionnables en glissant leur bord (double-clic : taille d'origine). Réglages conservés dans le navigateur.
- Sélectionner un élément rouvre le panneau et centre la frise sur sa période, en ramenant sa bande au milieu.
- **Téléphone et tablette en portrait** (largeur ≤ 900 px) : carte plein écran, pincement à deux doigts pour zoomer et se déplacer ; la fiche s'ouvre en volet depuis le bas (poignée : vers le haut pour l'agrandir, vers le bas pour la réduire puis la fermer, ✕ pour la fermer) ; la frise se réduit à un curseur d'années, dépliable par ▴ ; le bouton *Calques* regroupe les affichages ; les fenêtres passent en plein écran.
- Carte : boutons **+ / −**, touches **+ / −**, double-clic pour zoomer (Maj + double-clic pour dézoomer). La légende des civilisations affichées est supprimée au profit de la carte.
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


## Historique

- **2.3.1** — correctif : après un déplacement de la carte, les clics de placement (lieu, point d'événement) et de tracé étaient ignorés ; la carte se fait désormais glisser dans tous les modes.
- **2.3.0** — adaptation au téléphone : volet de fiche glissant, curseur d'années, pincement, menu Calques, fenêtres plein écran, infobulles désactivées au doigt.
- **2.2.0** — légende supprimée ; panneau et frise repliables et redimensionnables ; frise centrée sur la sélection ; zoom par boutons, clavier et double-clic ; imports JSON et enrichissement retirés de l'interface.
- **2.1.0** — relief ombré ; fiche Description et onglet Technique (édition sur place), images ; onglet Éléments retiré ; enrichissement non destructif (32 civilisations, 577 emprises datées) ; publication par lots.
- **2.0.0** — base partagée Supabase avec comptes, rôles et validation des propositions ; chargement automatique des données ; fond de carte multi-échelle 1:50M / 1:10M ; zoom ×5 ; coordonnées au millième de degré.
