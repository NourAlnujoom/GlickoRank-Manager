import sqlite3
import time
try:
    from real_data import (
        PREDEFINED_PLAYERS,
        PREDEFINED_RATINGS,
        PREDEFINED_RD,
        PREDEFINED_VOL,
        PREDEFINED_GROUP
    )

except ImportError:
    from seed_data import (
        PREDEFINED_PLAYERS,
        PREDEFINED_RATINGS,
        PREDEFINED_RD,
        PREDEFINED_VOL,
        PREDEFINED_GROUP
    )

DB_NAME = "players_db.db"

def init_db():
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    c.execute('''CREATE TABLE IF NOT EXISTS tier_settings
                (group_tier TEXT PRIMARY KEY, rating REAL, rd REAL, vol REAL)''')
    
    default_tiers = [
        ("Rookie", 1300.0, 200.0, 0.06),
        ("Challenger", 1500.0, 200.0, 0.06),
        ("Master", 1700.0, 200.0, 0.06),
        ("Grandmaster", 1900.0, 200.0, 0.06)
    ]
    c.executemany("INSERT OR IGNORE INTO tier_settings (group_tier, rating, rd, vol) VALUES (?, ?, ?, ?)", default_tiers)

    c.execute('''CREATE TABLE IF NOT EXISTS history_snapshots (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                batch_id TEXT,
                name TEXT,
                rating REAL,
                rd REAL,
                vol REAL,
                group_tier TEXT)''')

    c.execute('''CREATE TABLE IF NOT EXISTS players 
                (name TEXT PRIMARY KEY, 
                 rating REAL, 
                 rd REAL, 
                 vol REAL, 
                 group_tier TEXT,
                 FOREIGN KEY(group_tier) REFERENCES tier_settings(group_tier))''') 
    
    c.execute("SELECT count(*) FROM players")
    count = c.fetchone()[0]
    
    if count == 0:
        print("--- Database is empty. Seeding predefined players... ---")
        for i in range(len(PREDEFINED_PLAYERS)):
            c.execute("INSERT INTO players (name, rating, rd, vol, group_tier) VALUES (?, ?, ?, ?, ?)", 
                    (PREDEFINED_PLAYERS[i], PREDEFINED_RATINGS[i], PREDEFINED_RD[i], PREDEFINED_VOL[i], PREDEFINED_GROUP[i]))
        print("--- Seeding Complete. ---")
    else:
        print(f"--- Database has {count} players.---")
    
    conn.commit()    
    conn.close()

def get_tier_for_rating(rating):
    tiers = get_tier_settings()
    tiers.sort(key=lambda x: x['rating'])
    
    assigned_tier = tiers[0]['group_tier'] if tiers else "Rookie"
    
    for t in tiers:
        if rating >= t['rating']:
            assigned_tier = t['group_tier']
        else:
            break
    return assigned_tier

def get_tier_settings():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row 
    c = conn.cursor()
    c.execute("SELECT * FROM tier_settings")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def add_player(name, rating=1500.0, rd=200.0, vol=0.06):
    assigned_tier = get_tier_for_rating(rating)

    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("INSERT INTO players (name, rating, rd, vol, group_tier) VALUES (?, ?, ?, ?, ?)", 
            (name, rating, rd, vol, assigned_tier))
    conn.commit()
    conn.close()

def update_player(name, new_rating, new_rd, new_vol, new_tier):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("UPDATE players SET rating=?, rd=?, vol=?, group_tier=? WHERE name=?", 
            (new_rating, new_rd, new_vol, new_tier, name))
    conn.commit()
    conn.close()

def get_players():
    conn = sqlite3.connect(DB_NAME)
    conn.row_factory = sqlite3.Row 
    c = conn.cursor()
    c.execute("SELECT * FROM players")
    rows = c.fetchall()
    conn.close()
    return [dict(row) for row in rows]

def update_tier_baseline(group_tier, new_rating, new_rd, new_vol):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    c.execute("UPDATE tier_settings SET rating=?, rd=?, vol=? WHERE group_tier=?", 
            (new_rating, new_rd, new_vol, group_tier))
    conn.commit()
    conn.close()

def reset_tier_players(group_tier):
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
 
    c.execute("SELECT rating, rd, vol FROM tier_settings WHERE group_tier=?", (group_tier,))
    baseline = c.fetchone()
    
    if baseline:
        c.execute("UPDATE players SET rating=?, rd=?, vol=? WHERE group_tier=?", 
                 (baseline[0], baseline[1], baseline[2], group_tier))
        
    conn.commit()
    conn.close()


def create_snapshot():
    """Takes a photograph of the current database before a tournament."""
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    # Create a unique ID for this specific tournament using the current time
    batch_id = f"batch_{int(time.time())}"
    
    # Copy everyone's current stats into the history table
    c.execute("""
        INSERT INTO history_snapshots (batch_id, name, rating, rd, vol, group_tier)
        SELECT ?, name, rating, rd, vol, group_tier FROM players
    """, (batch_id,))
    
    conn.commit()
    conn.close()

def undo_last_tournament():
    """Finds the last photograph, restores the players, and deletes the photo."""
    conn = sqlite3.connect(DB_NAME)
    c = conn.cursor()
    
    # 1. Find the most recent batch_id
    c.execute("SELECT batch_id FROM history_snapshots ORDER BY id DESC LIMIT 1")
    result = c.fetchone()
    
    if not result:
        conn.close()
        return False # Nothing to undo!
        
    latest_batch = result[0]
    
    # 2. Grab the old stats for that batch
    c.execute("SELECT name, rating, rd, vol, group_tier FROM history_snapshots WHERE batch_id=?", (latest_batch,))
    old_stats = c.fetchall()
    
    # 3. Restore the players table to those old stats
    for stat in old_stats:
        c.execute("""
            UPDATE players 
            SET rating=?, rd=?, vol=?, group_tier=? 
            WHERE name=?
        """, (stat[1], stat[2], stat[3], stat[4], stat[0]))
        
    # 4. Delete the snapshot since we just undid it
    c.execute("DELETE FROM history_snapshots WHERE batch_id=?", (latest_batch,))
    
    conn.commit()
    conn.close()
    return True