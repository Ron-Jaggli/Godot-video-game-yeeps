class_name Quests
extends RefCounted
## Quest definitions. Quests count a stat (see Profile.record) up to a target
## and pay Teeth and Relics once. Daily quests reset at 00:00 UTC, weekly ones
## on Monday 00:00 UTC. Relic payouts are clipped by Economy.RELICS_WEEKLY_CAP.
## Only append; ids are stored in saves.

enum Period { DAILY, WEEKLY }

## Stats the game records.
const STAT_BLOCKS_PLACED := "blocks_placed"
const STAT_BELFRY := "belfry_reached"
const STAT_GRAVES_DUG := "graves_dug"

const ALL: Array[Dictionary] = [
	{id = "d_build", period = Period.DAILY, title = "Lay 25 blocks", stat = STAT_BLOCKS_PLACED, target = 25, teeth = 15, relics = 10},
	{id = "d_belfry", period = Period.DAILY, title = "Climb into the belfry", stat = STAT_BELFRY, target = 1, teeth = 5, relics = 10},
	{id = "d_dig", period = Period.DAILY, title = "Dig up a grave", stat = STAT_GRAVES_DUG, target = 1, teeth = 10, relics = 5},
	{id = "w_build", period = Period.WEEKLY, title = "Lay 300 blocks", stat = STAT_BLOCKS_PLACED, target = 300, teeth = 80, relics = 60},
	{id = "w_belfry", period = Period.WEEKLY, title = "Reach the belfry 10 times", stat = STAT_BELFRY, target = 10, teeth = 30, relics = 40},
	{id = "w_dig", period = Period.WEEKLY, title = "Dig up 7 graves", stat = STAT_GRAVES_DUG, target = 7, teeth = 40, relics = 30},
]


## Day number (UTC) a daily quest belongs to.
static func day_key(unix: int) -> int:
	return unix / 86400


## Week number (UTC, weeks start Monday) a weekly quest or the Relic cap belongs to.
static func week_key(unix: int) -> int:
	# 1970-01-01 was a Thursday; shift so weeks roll over on Monday.
	return (unix / 86400 + 3) / 7


static func period_key(period: Period, unix: int) -> int:
	return day_key(unix) if period == Period.DAILY else week_key(unix)
