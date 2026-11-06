# Générateur de guides

`build_guides.lua` transforme les parcours de `routes/` en guides pour l'addon
(`FreegorGuide/Guides/*.lua`).

## Données

Le générateur lit les données publiques de WoW Forever du projet
[QuestieDB](https://github.com/Questie/QuestieDB) (quêtes, PNJ, objets, noms français).
Seuls des faits du jeu (IDs, positions, noms) sont repris dans les guides ; le code et les
fichiers de QuestieDB ne sont pas inclus dans ce dépôt.

```bash
git clone --depth 1 https://github.com/Questie/QuestieDB /chemin/vers/QuestieDB
```

```bash
QUESTIEDB=/chemin/vers/QuestieDB lua5.1 tools/build_guides.lua
```

Le script affiche les avertissements (quête prise sous son niveau requis, prérequis manquant,
objectif introuvable ou hors de la zone) et échoue en cas d'erreur (ID inconnu, quête rendue
avant d'être acceptée...). Il affiche aussi les lignes à mettre dans le `.toc`.

## Écrire un parcours

`routes/ORDER` donne l'ordre de génération. Chaque ligne indique une chaîne (`human`, `dwarf`,
`nelf`, `main`) : les quêtes faites sont suivies par chaîne pour vérifier les prérequis, et la
chaîne `main` reprend les quêtes de toutes les chaînes de départ.

| Commande | Effet |
| --- | --- |
| `guide`, `faction`, `race`, `levels`, `next`, `author` | En-tête du guide (copié tel quel) |
| `area <zoneID>` | Zone par défaut (ID AreaTable : 12 Elwynn, 40 Marche de l'Ouest...) |
| `accept <quête> [pnj]` | Aller au donneur de quête, lui parler, accepter. Les quêtes du même PNJ sont regroupées. |
| `turnin <quête> [pnj]` | Pareil pour rendre la quête |
| `do <quête> [@x,y]` | Faire les objectifs : position calculée là où se trouvent les monstres / objets (ou forcée) |
| `+do <quête>` | Mêmes objectifs dans la même étape que la précédente |
| `talk <npcID>` | Aller parler à un PNJ |
| `goto [zoneID] x,y` | Déplacement |
| `home`, `fpath`, `fly`, `hearth`, `train`, `buy`, `note` | Actions (voir docs/FORMAT.md), ajoutées à l'étape du PNJ courant |
| `+ <ligne>` | Ligne de guide brute ajoutée à l'étape courante |
| `only <classes/races>` | Restreint la prochaine étape |
| `level <n>` | Étape « atteindre le niveau n » |
| `lvl <n>` | Niveau attendu à ce point (pour les vérifications, sans créer d'étape) |
| `step` | Coupure : sépare deux groupes de visites de PNJ |

## Regroupement automatique

Les visites de PNJ qui se suivent dans un parcours (prendre ou rendre des quêtes, foyer,
point de vol) forment un groupe. Le générateur réordonne chaque groupe : il fait tout ce qui
est possible chez un PNJ, puis va au PNJ le plus proche qui a quelque chose de disponible,
sans jamais prendre une quête avant son prérequis. Les PNJ proches les uns des autres sont
réunis dans une même étape ; la flèche passe de l'un à l'autre au fil des quêtes.
Un `fly` ou un `hearth` termine le groupe.

Pour les objectifs, le générateur choisit la zone dense de monstres ou d'objets la plus proche
de l'endroit où se trouve le joueur à ce moment du parcours. Il signale aussi les quêtes dont
les objectifs sont à côté de leur donneur mais que le parcours ne fait qu'après un détour, et
les PNJ revisités juste après (normalement seulement quand un prérequis l'impose).
