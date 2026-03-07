from database import (init_db, add_player as db_add_player, get_players, update_player, get_tier_settings, update_tier_baseline, reset_tier_players, get_tier_for_rating, create_snapshot, undo_last_tournament)
from glicko2 import Player
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

app = FastAPI()
players = {}

def reload_players_in_memory():
    global players
    players.clear()
    raw_data = get_players()
    for p in raw_data:
        players[p['name']] = Player(rating=p['rating'], rd=p['rd'], vol=p['vol'])

init_db()
reload_players_in_memory()

current_tournament_games = []

class PlayerInput(BaseModel):
    name: str
    rating: float = 1500.0
    rd: float = 200.0
    vol: float = 0.06

class GameInput(BaseModel):
    player1_name: str
    player2_name: str
    result: float

class TierUpdateInput(BaseModel):
    group_tier: str
    rating: float
    rd: float
    vol: float

class TierResetInput(BaseModel):
    group_tier: str

@app.get("/players")
def get_all_players():
    return get_players()

@app.post("/players")
def create_player(player: PlayerInput):
    db_add_player(player.name, player.rating, player.rd, player.vol)
    players[player.name] = Player(rating=player.rating, rd=player.rd, vol=player.vol)
    return {"message": f"Player {player.name} added successfully"}

@app.post("/games")
def add_game(game: GameInput):
    if game.player1_name not in players or game.player2_name not in players:
        raise HTTPException(status_code=404, detail="One or both players not found")
    
    if game.player1_name == game.player2_name:
        raise HTTPException(status_code=400, detail="Cannot play against yourself")
        
    current_tournament_games.append(game)
    return {"status": "Game added", "queue_length": len(current_tournament_games)}

@app.post("/tournament/process")
def process_tournament():
    global current_tournament_games
    if not current_tournament_games: return {"message": "No games to process"}
    create_snapshot()
    
    changes = {}
    for game in current_tournament_games:
        result = game.result
        p1 = game.player1_name
        p2 = game.player2_name

        if p1 not in changes: changes[p1] = []
        changes[p1].append((p2, result))

        if p2 not in changes: changes[p2] = []
        changes[p2].append((p1, 1.0 - result))

    response_data = []
    for name, matches in changes.items():
        if name not in players: continue
        
        player_obj = players[name]
        old_rating = player_obj.rating
        old_rd = player_obj.rd
        old_vol = player_obj.vol
        opponent_ratings = []
        opponent_rds = []
        outcomes = []

        for opponent_name, outcome in matches:
            if opponent_name not in players: continue
            opponent_obj = players[opponent_name]
            opponent_ratings.append(float(opponent_obj.rating))
            opponent_rds.append(float(opponent_obj.rd))
            outcomes.append(float(outcome))
        
        player_obj.update_player(opponent_ratings, opponent_rds, outcomes)

        new_tier = get_tier_for_rating(player_obj.rating)

        update_player(
            name=name, 
            new_rating=player_obj.rating, 
            new_rd=player_obj.rd, 
            new_vol=player_obj.vol, 
            new_tier=new_tier
        )

        response_data.append({
            "name": name,
            "old_rating": round(old_rating, 2),
            "new_rating": round(player_obj.rating, 2),
            "old_rd": round(old_rd, 2),
            "new_rd": round(player_obj.rd, 2),
            "old_vol": round(old_vol, 4),
            "new_vol": round(player_obj.vol, 4),
            "new_tier": new_tier
        })
    current_tournament_games = []
    
    return response_data

@app.get("/tiers")
def get_tiers():
    return get_tier_settings()

@app.post("/tiers/update")
def update_tier(tier: TierUpdateInput):
    update_tier_baseline(tier.group_tier, tier.rating, tier.rd, tier.vol)
    return {"message": f"{tier.group_tier} baseline updated successfully."}

@app.post("/tiers/reset")
def reset_tier(reset: TierResetInput):
    reset_tier_players(reset.group_tier)
    reload_players_in_memory() # Ensure RAM matches the reset DB
    return {"message": f"All {reset.group_tier} players reset to baseline."}

@app.post("/tournament/undo")
def undo_tournament():
    success = undo_last_tournament()
    if success:
        reload_players_in_memory() # Sync the RAM back to the old stats!
        return {"message": "Tournament successfully undone. Ratings restored."}
    else:
        raise HTTPException(status_code=400, detail="No tournament history found to undo.")