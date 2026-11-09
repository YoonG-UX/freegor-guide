# Freegor Guide

Deux addons dans ce dépôt :

| Dossier | Jeu | Contenu |
| --- | --- | --- |
| `FreegorGuide` | WoW Forever (interface 16001) | Leveling 1-30 Alliance et Horde, montures, récolte, réputation, points de vol |
| `FreegorGuideRetail` | World of Warcraft Retail (12.1.5, interface 120105) | Métiers, montures, hauts faits, construits à partir des données de votre jeu |

N'installez que le dossier qui correspond à votre jeu.

## Version Retail

Les guides Retail sont **générés en jeu** à partir des données du client, ils suivent donc
chaque patch sans mise à jour du guide :

- **Métiers** (un guide par métier du personnage) : ouvrez une fois la fenêtre du métier sur
  l'onglet de l'extension à monter. Le guide donne **le parcours complet jusqu'au maximum** :
  « niveaux 12 à 25 : fabriquez environ 18 x Recette », avec les composants de chaque étape.
  Il s'appuie sur les seuils de couleur exacts de chaque recette (orange, jaune, verte, grise),
  extraits des tables du client de jeu (10 723 recettes, toutes extensions), et sur les recettes
  que votre personnage connaît. Si vos recettes ne suffisent pas pour atteindre le maximum, il
  liste celles à apprendre. Sans seuils connus, il indique la prochaine recette à fabriquer (celle qui
  rapporte le plus de points pour le moins de composants ; avec Auctionator, selon les prix de
  l'hôtel des ventes), combien en faire, les composants avec ce que vous possédez déjà (sacs,
  banque, banque de composants, banque de bataillon), le niveau visé, un second choix et les
  premières fabrications qui donnent des points de connaissance. Cliquer sur une recette l'ouvre.
  Il se recalcule après chaque fabrication.
- **Collection de montures** (`/fg mounts`, ou le bouton de la catégorie Montures du menu) :
  toutes les montures du journal, avec votre progression, une recherche et des filtres
  (manquantes / obtenues / toutes, par source). Pour chaque monture : son modèle 3D (à faire
  tourner à la souris), sa description et comment l'obtenir — source donnée par le jeu, boss et
  instance avec l'entrée sur la carte et « déjà tué cette semaine » ou « disponible », haut fait
  avec sa progression et les critères restants. Boutons : **Me guider** (flèche et étapes),
  **Suivre** (liste de suivi), **Invoquer**, **Lien** dans le chat.
- **Montures** : toutes les montures que vous n'avez pas, d'après le journal des montures.
  - *Ma liste de suivi* : les montures que vous chassez, avec la façon d'obtenir chacune.
  - *Butin de donjons et raids* : boss et instance lus dans la source de la monture, flèche vers
    l'entrée de l'instance (journal des donjons), contenu ancien d'abord ; les boss déjà tués
    cette semaine sont masqués jusqu'à la réinitialisation.
  - *Hauts faits* : la monture, son haut fait, la progression et les critères restants, les plus
    avancés d'abord.
  - *Vendeurs* et *Quêtes, événements et découvertes* : la source indiquée par le jeu.
- **Hauts faits presque terminés** : vos hauts faits les plus avancés et ce qu'il leur manque.

Une étape ne vous intéresse pas ? « Suivant » la masque (`/fg unskip` pour tout réafficher).

Limites : le jeu ne donne pas la position des vendeurs ni des ressources à récolter ; les guides
de vendeurs et de métiers de récolte n'ont donc pas de flèche.

Guide de leveling pas à pas pour World of Warcraft (client WoW Forever), **gratuit et communautaire**.
Fenêtre d'étapes, validation automatique des objectifs, flèche de navigation, compatible TomTom.

## Guides inclus : Alliance 1-30

| Niveaux | Humain | Nain / Gnome | Elfe de la nuit |
| --- | --- | --- | --- |
| 1-6 | Comté-du-Nord | Vallée de Froide-Combe | Sombrevallon |
| 6-11 | Forêt d'Elwynn | Dun Morogh | Teldrassil |
| 11-16 | Marche de l'Ouest | Loch Modan | Sombrivage (11-17) |
| 16-21 | Les Carmines | | |
| 21-25 | Bois de la Pénombre | | |
| 25-28 | Les Paluns | | |
| 28-30 | Bois de la Pénombre et Les Carmines | | |

## Guides inclus : Horde 1-30

| Niveaux | Orc / Troll | Tauren | Mort-vivant |
| --- | --- | --- | --- |
| 1-6 | Vallée des Épreuves | Camp Narache | Le Glas |
| 6-11 | Durotar | Mulgore | Clairières de Tirisfal |
| 11-16 | Les Tarides | Les Tarides | Bois des Pins-Argentés |
| 16-21 | Les Tarides | | |
| 21-24 | Serres-Rocheuses | | |
| 24-30 | Contreforts de Hautebrande | | |

Les autres catégories du menu existent aussi pour la Horde : montures de chaque race
(loups, raptors, kodos, chevaux squelettes), circuits de minage et d'herboristerie (Durotar,
Mulgore, Tirisfal, Pins-Argentés, Tarides, Serres-Rocheuses, Hautebrande), farm de tissu à
Hautebrande, dons de tissu aux quatre capitales et tous les points de vol de la Horde.

À la première connexion, le guide adapté à votre race et à votre niveau est chargé tout seul.
Chaque guide propose le suivant à la fin.

## Le menu : que voulez-vous suivre ?

Ouvrez le menu avec le bouton de la minicarte (clic gauche) ou `/fg menu`. Les guides sont
rangés par catégorie ; la progression de chaque guide est mémorisée, vous pouvez passer de
l'un à l'autre et revenir.

| Catégorie | Guides |
| --- | --- |
| Montée de niveau | Alliance 1-30 (voir ci-dessus) |
| Montures | Monture du niveau 40 pour chaque race : maître de monte, vendeur, or nécessaire (Paladin et Démoniste : monture de classe) |
| Or et récolte | Circuits en boucle : minage (cuivre, étain, argent), herboristerie, farm de tissu sur les Défias |
| Réputation | Dons de tissu (laine, soie, tisse-mage, étoffe runique) aux quatre capitales |
| Hauts faits et collections | Tous les points de vol de l'Alliance (Royaumes de l'Est, Kalimdor) |

WoW Forever reprend le contenu de Classic, qui n'a pas de système de hauts faits.
Les guides de cette catégorie suivent donc des objectifs que le jeu sait vérifier
(points de vol découverts...). Le format accepte aussi des objectifs `achieve <id>`, qui
s'activeront tout seuls si le client a des hauts faits.

## Installation

1. Téléchargez ce dépôt (bouton *Code → Download ZIP*).
2. Copiez le dossier `FreegorGuide` dans `World of Warcraft/_<version>_/Interface/AddOns/`.
3. Relancez le jeu et activez **Freegor Guide** dans la liste des addons.

## Utilisation

| Commande | Effet |
| --- | --- |
| `/freegor` ou `/fg` | Afficher / masquer la fenêtre |
| `/freegor menu` | Ouvrir le menu des guides |
| `/freegor minimap` | Afficher / masquer le bouton de la minicarte |
| `/freegor next`, `/freegor prev` | Étape suivante / précédente |
| `/freegor step 12` | Aller à l'étape 12 |
| `/freegor arrow` | Afficher / masquer la flèche |
| `/freegor auto` | Activer / désactiver l'acceptation et le rendu automatiques des quêtes du guide |
| `/freegor reset` | Remettre les fenêtres à leur place |

- Les étapes avancent toutes seules quand le jeu détecte l'action demandée :
  quête acceptée, objectif rempli, quête rendue, niveau atteint, arrivée à destination,
  dialogue avec le bon PNJ, pierre de foyer liée, point de vol découvert, vol pris,
  pierre de foyer utilisée, visite au maître de classe.
- Les quêtes déjà terminées sont reconnues : en chargeant un guide, vous reprenez directement
  à la première quête qu'il vous reste à faire.
- Avec `/freegor auto`, les quêtes du guide sont acceptées et rendues automatiquement
  (maintenez Maj pour suspendre ; les quêtes avec un choix de récompense restent manuelles).
- Cliquez sur une ligne « Aller en… » pour y placer la flèche.
- La fenêtre et la flèche se déplacent à la souris ; leur position est sauvegardée.
- La progression est sauvegardée par personnage.

## Écrire un guide

Les guides sont du texte simple. Exemple :

```
guide Northshire Valley (1-6)
faction Alliance
levels 1-6
zone 1429, Elwynn Forest, Forêt d'Elwynn

step
  goto 48.2,42.0
  talk Deputy Willem
  accept 783 A Threat Within
step
  kill 10 Kobold Vermin |q 7/1
```

Le format complet est décrit dans [docs/FORMAT.md](docs/FORMAT.md).

Les guides fournis sont **générés** à partir de parcours courts (`tools/routes/*.route`) :
on y écrit l'ordre des quêtes, et le générateur ajoute les PNJ, les coordonnées et les noms
français, puis vérifie les enchaînements de quêtes. Voir [tools/README.md](tools/README.md).
Un autre addon peut aussi fournir ses propres guides (pack de guides) avec `## Dependencies: FreegorGuide`
et des appels à `Freegor:RegisterGuide([[ ... ]])`.

## Contribuer

- Les IDs de quêtes, PNJ et coordonnées viennent des données publiques de WoW Forever
  (base de données QuestieDB). Signalez toute étape fausse en jeu avec le nom du guide et le numéro d'étape.
- Lancez les tests avant de proposer une modification :

```bash
lua5.1 tests/run.lua
```

Les tests chargent l'addon avec une API WoW simulée : ils vérifient la syntaxe, le chargement du `.toc`,
l'analyse des guides et l'avancement automatique des étapes. Ils ne remplacent pas un essai en jeu.

## Signaler un bug

Activez les erreurs Lua (`/console scriptErrors 1`) ou installez BugSack, puis ouvrez une *issue*
avec le message d'erreur complet, la version du client et l'étape du guide concernée.
