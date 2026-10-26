# Atlas des civilisations — v2.0.0

Atlas historique interactif (5000 av. J.-C. → 1900) : carte et frise synchronisées, territoires, lieux, événements, filiations, tutelles.

## Contenu du dépôt

| Fichier | Rôle |
|---|---|
| `index.html` | l'application (page unique) |
| `config.js` | URL et clé publique Supabase — à renseigner |
| `data/atlas.json` | jeu de données : initialisation de la base et copie de secours |
| `data/geo/base.json` | fond de carte 1:50 000 000 (vue d'ensemble) |
| `data/geo/t/*.json` | 464 tuiles 10° × 10° au 1:10 000 000, chargées au zoom |
| `supabase/schema_v2.0.0.sql` | tables, règles d'accès (RLS) et fonctions |
| `tools/build_geo.py` | régénère `data/geo` depuis Natural Earth |
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

## Exploitation

- **Copie de secours** : *Données › Exporter (.json)* puis remplacer `data/atlas.json` dans le dépôt. Ce fichier est affiché, en lecture seule, si la base est injoignable.
- **Restauration d'un élément** : consulter `item_history` (colonne `old_data`) dans Supabase.
- **Envoi des e-mails** : le service d'envoi intégré à Supabase est limité à quelques messages par heure ; pour un usage public, configurer un SMTP (*Project Settings › Authentication › SMTP Settings*).
- **Mise en veille** : un projet gratuit inactif une semaine est suspendu ; il se réactive depuis le tableau de bord. Pendant ce temps, le site affiche la copie de `data/atlas.json`.
- **Test local** : `python3 -m http.server` à la racine du dépôt, puis http://localhost:8000 (l'ouverture directe du fichier ne permet pas de charger les données).

## Fond de carte

Natural Earth (domaine public) : 1:50 000 000 en vue d'ensemble, tuiles 1:10 000 000 sous 48° de largeur de vue. Les réservoirs modernes sont retirés ; la mer d'Aral et le lac Tchad sont dans leur emprise historique. Régénération :

```bash
pip install shapely
# télécharger dans ./ne les GeoJSON ne_50m_* et ne_10m_* : land, lakes, lakes_historic, rivers_lake_centerlines
# (github.com/nvkelso/natural-earth-vector, dossier geojson)
python3 tools/build_geo.py ./ne ./data/geo
```

## Historique

- **2.0.0** — base partagée Supabase avec comptes, rôles et validation des propositions ; chargement automatique des données ; fond de carte multi-échelle 1:50M / 1:10M ; zoom ×5 ; coordonnées au millième de degré.
