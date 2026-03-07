# GlickoRank Manager

A mobile application designed to manage competitive player rankings and tournament processing using a custom Glicko-2 mathematics engine. 

## Tech Stack
* **Frontend:** Flutter & Dart
* **Backend:** Python & FastAPI
* **Database:** SQLite3 

## Features
* **Glicko-2 Engine:** Calculates and updates player ratings, Rating Deviation (RD), and Volatility after every processed tournament.
* **Dynamic Tiering System:** Automatically sorts players into dynamic groups (Rookie, Challenger, Master, Grandmaster) based on adjustable mathematical baselines.
* **Batch Processing:** Queues up multiple games and processes them as a single tournament batch to ensure accurate calculations.
* **Snapshot "Time Machine":** Includes a custom database ledger that takes a pre-tournament snapshot, allowing administrators to instantly undo the last tournament and cleanly revert all player stats.

You can safely fill player information inside `seed_data.py`.
You MUST check `api_service.dart` before running to adjust the connection configuration.
