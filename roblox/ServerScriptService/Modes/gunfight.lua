--!strict
-- Modes/gunfight : Gunfight (Call of Duty), 1 v 1 à 4 v 4 (2 v 2 par défaut) : manches de 40 s sans bombe ni réapparition,
-- 5 s de préparation, pas de boutique : tout le monde reçoit les MÊMES armes (principale + pistolet + grenade ou flash),
-- tirées au sort toutes les 2 manches. Positions révélées à 15 s de la fin ; au temps, l'équipe avec le plus de survivants
-- puis le plus de points de vie gagne la manche. Premier à 6 manches par défaut. Toutes les règles sont dans Modes/rounds.
return require(script.Parent.rounds).make("gunfight")
