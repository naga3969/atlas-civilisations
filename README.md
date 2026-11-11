# Atlas des civilisations — v2.8.0

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
| `supabase/migration_v2.8.0.sql` | ajoute les collections des personnages et des dynasties (à exécuter après le schéma) |
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

1. **Supabase** — créer un projet sur supabase.com, puis *SQL Editor* › coller et exécuter `supabase/schema_v2.0.0.sql`, puis `supabase/migration_v2.8.0.sql`.
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

## Mise à jour vers la v2.8.0

1. **D'abord**, dans Supabase › *SQL Editor*, coller et exécuter `supabase/migration_v2.8.0.sql` (rejouable sans risque). Il autorise les collections *persons* et *dynasties* ; sans lui, la publication d'un personnage ou d'une dynastie est refusée par la base. Il remplace l'ancien `migration_v2.4.0.sql`, qui n'a jamais été déposé dans le dépôt.
2. Copier `index.html`, `README.md` et `supabase/migration_v2.8.0.sql`, commit, **push**.

Rien à convertir : faits, parents, conjoints et dynasties de rattachement sont de nouveaux champs facultatifs.

## Mise à jour vers la v2.7.0

Aucun script SQL. Copier `index.html` et `README.md`, commit, **push**.

## Mise à jour vers la v2.6.0

1. Aucun script SQL : les nouveautés (rattachement d'une emprise à une période, rapprochements et suggestions écartés) sont de simples champs facultatifs des données existantes. Il suffit que la migration v2.4.0 ci-dessous ait déjà été exécutée.
2. Copier `index.html` et `README.md`, commit, push.

## Mise à jour vers la v2.4.0

La migration des personnages est incluse dans `supabase/migration_v2.8.0.sql`.

## Données

L'enrichissement v2.1.0 (civilisations supplémentaires, emprises datées) est désormais intégré à la base ; l'application ne propose plus d'import. Le fichier `data/enrichissement_v2.1.0.json` peut être retiré du dépôt, **après** avoir déposé un export à jour (*Données › Exporter (.json)*) à la place de `data/atlas.json`, qui sert de copie de secours et d'initialisation.

## Interface

- **Frise d'une entité** : cliquer une civilisation, un lieu ou un personnage n'affiche que sa frise, cadrée sur sa durée — pistes Périodes, Règnes, Guerres et batailles, Traités, Événements, Personnages ; pour une civilisation, la courbe de son étendue territoriale (calculée sur les emprises) et ses tutelles ; pour un lieu, qui le contrôlait (calculé à partir des territoires tracés). **← Toutes** revient à l'ensemble.
- **Priorité au contenu** : dans la frise, seules les pistes remplies s'affichent, dans l'ordre ; les vides sont regroupées en bas sur une seule ligne (*Ajouter*), visible des seuls comptes autorisés. Le titre d'une piste est incrusté sur sa première rangée. Les fiches de lieu, d'entrée et de personnage suivent la même règle (*Compléter*).
- **Continuité** : dans la frise d'une civilisation, de courtes amorces montrent ce qui la précède (← à gauche) et la suit (→ à droite), sans allonger la frise. Elles viennent des filiations déclarées ; à défaut, des civilisations qui se succèdent à quelques décennies près sur le même territoire (trait pointillé, « filiation non déclarée »). Un clic ouvre la civilisation.
- **Navigation dans la frise** : molette = défiler les bandes ; **Ctrl** + molette (ou pincement du pavé tactile) = zoom ; **Maj** + molette = avancer ou reculer dans le temps ; une barre fine sous la frise montre la fenêtre affichée et se fait glisser. La molette seule continue de zoomer la carte.
- **Entrées croisées** : une entrée n'existe qu'une fois mais se relie à plusieurs civilisations (chacune avec son rôle : principal, vainqueur, vaincu, allié, belligérant, signataire, fondateur, concerné), à plusieurs lieux et à plusieurs personnages (souverain, commandant, fondateur, auteur, signataire, participant) ; elle apparaît dans la frise et la fiche de chacun. Une entrée peut faire partie d'une autre (une bataille dans une guerre). Les boutons **+** des pistes et des sections créent une entrée déjà reliée à l'élément affiché.
- **Personnages** : fiches à part (dates, titre, biographie, image, civilisations de rattachement), recherchables.
- **Lieux** : *Technique › Rattacher les entrées proches* propose les entrées localisées à moins de 30 km.
- Supprimer une civilisation conserve les entrées partagées : la civilisation suivante devient principale.
- **Fiches** : civilisation, lieu, entrée, personnage et dynastie s'ouvrent sur un **résumé** dans le panneau (dates, début du texte, repères, compteurs qui ouvrent la fiche complète sur le bon onglet ; pour les comptes autorisés, un bloc *À compléter*). **Fiche complète** ouvre une vue large au-dessus de la carte, la frise restant visible ; **Échap** la referme. Onglets selon le type :
  - *Civilisation* : Aperçu, Chronologie, Relations (filiations déclarées ou suggérées, tutelles), Géographie (bande de couverture, emprises avec leur période, lieux) ;
  - *Lieu* : Aperçu, Chronologie, Contrôle (qui le tenait, calculé d'après les territoires ; civilisation de rattachement ; personnages), Géographie (position, entrées localisées à moins de 30 km à rattacher) ;
  - *Entrée* : Aperçu, Chronologie de ses étapes (pour un **épisode** : guerre, période, règne, entrée longue ou qui a des étapes), Participants (civilisations et personnages avec leur rôle, civilisation principale, filiations dont elle est l'événement de transition), Géographie (point, mouvements, lieux, étapes placées, emprises rattachées pour une période). Une étape propose ← précédente · ↑ épisode · suivante → ;
  - *Personnage* : Aperçu (dont sexe, lieux de naissance et de mort), **Famille** (parents naturels ou adoptifs, conjoints datés, enfants et fratrie calculés, petit arbre sur deux générations, dynasties), Chronologie (avec son rôle et ses faits de vie), Relations (civilisations rattachées ou présentes dans ses entrées, lieux, personnages croisés) ;
  - *Dynastie* : Aperçu (civilisations, **issue de** : union, branche cadette ou changement de nom ; branches qui en sont issues), **Arbre** généalogique complet (par générations ou sur l'échelle du temps, adoptions, conjoints et parents extérieurs, fil de la succession, souverains numérotés), Souverains, Territoires gouvernés (emprise au milieu de chaque règne), Chronologie.
- **Dirigeants** (onglet d'une civilisation) : ses souverains dans l'ordre, regroupés par dynastie, avec ruban chronologique, co-souverains, durée, **lien de parenté avec le précédent** (calculé d'après les familles ; en orange quand il passe par une adoption) et périodes sans souverain saisi. La **saisie rapide** (années + nom + dynastie) crée en une fois le règne et, si besoin, le personnage. La liste repose sur les entrées « Règne » où un personnage a le rôle Souverain.
- **Faits** : événements légers, sans fiche, rangés dans l'élément qu'ils concernent — personnage (naissance et mort d'après ses dates, mariage, adoption, avènement, abdication, exil, captivité), lieu (fondation, changement de nom, destruction, reconstruction, séisme, capitale), civilisation (changement de capitale ou de nom, réforme), dynastie (fondation, extinction, union, changement de nom). Ils s'ajoutent en série dans l'onglet Chronologie (**+ Fait**), apparaissent sur la frise propre de l'élément, et **→ entrée** les transforme en entrée complète.
- **Saisie des noms** : partout où l'on relie un personnage (parents, conjoints, enfants, membres, souverains), on tape un nom existant ou nouveau ; un nom inconnu crée le personnage.
- **Navigation de fiche en fiche** : dans la fiche complète, chaque nom (civilisation, lieu, entrée, personnage) ouvre sa fiche sans quitter la vue ; **← Retour** revient à la précédente. La frise et la carte suivent.
- **Édition sur place** (comptes autorisés) : chaque bloc de l'Aperçu a son crayon ✎ et son propre *Enregistrer* ; dans une Chronologie, ✎ corrige une entrée dans sa ligne (dates, intitulé, nature, rôle) et **+ Entrée** / **+ Étape** permet la saisie en série (Entrée enregistre et ouvre la ligne suivante, Échap arrête) ; ⋯ ouvre le formulaire complet. Les participants, lieux et civilisations de rattachement s'ajoutent, se retirent et changent de rôle directement dans leurs listes. Dans un épisode, **Appliquer aux étapes** reporte ses civilisations et personnages sur les étapes cochées, sans rien retirer ni modifier. L'onglet *Technique* n'existe plus.
- **Frise d'un épisode** : sélectionner un épisode (ou une de ses étapes) affiche sa frise propre, cadrée sur sa durée, avec ses étapes et ses personnages ; **↑** dans son en-tête revient à la frise de sa civilisation.
- **Périodes et emprises** : une période (entrée de la chronologie) et une emprise (tracé) restent indépendantes ; une emprise peut être rattachée à une période. Les formulaires proposent *Reprendre nom et dates* de l'une vers l'autre, avec une case pour les relier. Une période et une emprise de même nom, ou de dates presque identiques, sont signalées : *Rattacher* ou *Écarter*. Supprimer une période détache ses emprises sans les toucher.
- Sans sélection, la fiche liste les civilisations présentes à l'année du curseur.
- **Panneau latéral et frise** repliables (bouton *Panneau*, flèche ▾ de la frise, touches **P**, **F**, **C** pour la carte seule) et redimensionnables en glissant leur bord (double-clic : taille d'origine). Réglages conservés dans le navigateur.
- Sélectionner un élément rouvre le panneau et centre la frise sur sa période, en ramenant sa bande au milieu.
- **Téléphone et tablette en portrait** (largeur ≤ 900 px) : carte plein écran, pincement à deux doigts pour zoomer et se déplacer ; la fiche s'ouvre en volet depuis le bas (poignée : vers le haut pour l'agrandir, vers le bas pour la réduire puis la fermer, ✕ pour la fermer) et la fiche complète en plein écran, ses tableaux présentés en cartes ; la frise se réduit à un curseur d'années, dépliable par ▴ ; le bouton *Calques* regroupe les affichages ; les fenêtres passent en plein écran.
- Carte : boutons **+ / −**, touches **+ / −**, double-clic pour zoomer (Maj + double-clic pour dézoomer). La légende des civilisations affichées est supprimée au profit de la carte.
- Les images sont de simples adresses `https://` (Wikimedia Commons de préférence) ; rien n'est stocké dans la base. Elles s'affichent en **vignettes discrètes** ; un clic les agrandit.

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

- **2.8.0** — familles (parents naturels ou adoptifs, conjoints, enfants et fratrie calculés) ; type **Dynastie** avec arbre généalogique automatique, souverains, territoires gouvernés et filiation entre maisons (union, branche, changement de nom) ; onglet **Dirigeants** des civilisations avec lien de parenté avec le prédécesseur et saisie rapide des règnes ; **faits** légers sans fiche pour personnages, lieux, civilisations et dynasties ; sexe et lieux de naissance et de mort des personnages ; frises propres des dynasties ; recherche des dynasties. Migration SQL `migration_v2.8.0.sql`.
- **2.7.0** — fiches résumé + fiche complète pour les lieux, entrées et personnages (onglet Technique supprimé) ; navigation de fiche en fiche avec ← Retour ; entrées « épisode » avec chronologie de leurs étapes, frise propre et *Appliquer aux étapes* ; étapes précédente / suivante ; participants, lieux et rattachements modifiables dans les listes ; entrées proches d'un lieu à rattacher ; images en vignettes agrandissables. Pas de migration SQL.
- **2.6.0** — fiche civilisation refondue : résumé dans le panneau, fiche complète à onglets (Aperçu, Chronologie, Relations, Géographie) modifiable bloc par bloc, tableau des entrées avec correction dans la ligne et saisie en série, suggestions de filiation à déclarer, bande de couverture des emprises ; périodes et emprises reliables (*Reprendre nom et dates*, rapprochements à rattacher ou écarter). Pas de migration SQL.
- **2.5.0** — frise d'entité compacte (titres incrustés, pistes vides regroupées), sections remplies en priorité dans la fiche, amorces de continuité avant/après, molette de frise : Ctrl = zoom, Maj = déplacement, barre de navigation.
- **2.4.0** — chronologie croisée : frise propre à chaque civilisation, lieu et personnage ; entrées typées (période, règne, guerre, bataille, traité…) reliées à plusieurs civilisations avec rôle, lieux et personnages ; fiches Personnage ; courbe d'étendue ; contrôle d'un lieu calculé ; migration SQL v2.4.0.
- **2.3.1** — correctif : après un déplacement de la carte, les clics de placement (lieu, point d'événement) et de tracé étaient ignorés ; la carte se fait désormais glisser dans tous les modes.
- **2.3.0** — adaptation au téléphone : volet de fiche glissant, curseur d'années, pincement, menu Calques, fenêtres plein écran, infobulles désactivées au doigt.
- **2.2.0** — légende supprimée ; panneau et frise repliables et redimensionnables ; frise centrée sur la sélection ; zoom par boutons, clavier et double-clic ; imports JSON et enrichissement retirés de l'interface.
- **2.1.0** — relief ombré ; fiche Description et onglet Technique (édition sur place), images ; onglet Éléments retiré ; enrichissement non destructif (32 civilisations, 577 emprises datées) ; publication par lots.
- **2.0.0** — base partagée Supabase avec comptes, rôles et validation des propositions ; chargement automatique des données ; fond de carte multi-échelle 1:50M / 1:10M ; zoom ×5 ; coordonnées au millième de degré.
