local _, ns = ...
if GetLocale() ~= "frFR" then return end

local L = ns.L

L.NO_GUIDE        = "Aucun guide chargé. Cliquez sur le livre pour en choisir un."
L.STEP_FMT        = "Étape %d / %d"
L.GUIDE_DONE      = "Guide terminé !"
L.NEXT_GUIDE      = "Guide suivant : %s"
L.LOAD_NEXT       = "Charger le guide suivant"
L.CHOOSE_GUIDE    = "Choisir un guide"
L.PREV            = "Étape précédente"
L.NEXT            = "Étape suivante"
L.SKIP_HINT       = "Cliquez sur un objectif pour placer le repère. Les flèches changent d'étape."
L.MANUAL_HINT     = "Cliquez sur « Suivant » une fois terminé."
L.ARRIVED         = "Vous êtes arrivé."
L.YARDS_FMT       = "%d m"
L.OTHER_ZONE      = "La destination est dans une autre zone : %s"
L.LOADED_FMT      = "Guide chargé : %s"
L.UNKNOWN_GUIDE   = "Guide inconnu : %s"
L.PARSE_ERROR_FMT = "Erreur dans le guide « %s », ligne %d : %s"
L.FILTER_ALL      = "Tous"
L.LEVELS_FMT      = "niveaux %d-%d"

L.GOAL_ACCEPT  = "Accepter |cffffd100%s|r"
L.GOAL_TURNIN  = "Rendre |cffffd100%s|r"
L.GOAL_KILL    = "Tuer %s"
L.GOAL_COLLECT = "Récupérer %s"
L.GOAL_DO      = "Terminer |cffffd100%s|r"
L.GOAL_TALK    = "Parler à |cff00ff96%s|r"
L.GOAL_GOTO    = "Aller en %s"
L.GOAL_LEVEL   = "Atteindre le niveau %d"
L.GOAL_HOME      = "Lier votre pierre de foyer à |cff00ff96%s|r"
L.GOAL_FPATH     = "Découvrir le point de vol de |cff00ff96%s|r"
L.GOAL_FLY       = "Prendre le vol pour |cff00ff96%s|r"
L.GOAL_HEARTH    = "Utiliser votre pierre de foyer"
L.GOAL_HEARTH_TO = "Pierre de foyer vers |cff00ff96%s|r"
L.GOAL_TRAIN     = "Voir votre maître de classe"
L.GOAL_USE       = "Utiliser %s"
L.GOAL_BUY       = "Acheter %s"
L.AUTO_ON        = "Acceptation/rendu automatique des quêtes : |cff00ff00activé|r (Maj pour suspendre)"
L.AUTO_OFF       = "Acceptation/rendu automatique des quêtes : |cffff4040désactivé|r"
L.QUEST_FMT    = "quête n°%d"

L.HELP = {
  "/freegor - afficher ou masquer la fenêtre du guide",
  "/freegor list - choisir un guide",
  "/freegor next | prev - changer d'étape",
  "/freegor step <n> - aller à une étape",
  "/freegor arrow - afficher ou masquer la flèche",
  "/freegor auto - activer ou non l'acceptation/le rendu automatique des quêtes",
  "/freegor reset - réinitialiser la position de la fenêtre",
}
