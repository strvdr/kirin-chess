
# Kirin Chess Engine
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

The original Kirin Chess Engine was written in C and the source code is available [here](https://github.com/strvdr/kirin-ce). I have since deprecated this project and am now writing the Kirin Chess Engine in Zig. 


## Authors

- [Strydr Silverberg - @strvdr](https://www.github.com/strvdr)

## Documentation

I write a daily devlog which you can view at [strydr.net](https://strydr.net/articles). These devlogs are meant to serve as a walk through my thought process while building Kirin, as well as a limited form of documentation of the project. 

Kirin also has a documentation website, [kirin.strydr.net](https://kirin.strydr.net). This is a great place to start, and I will try and keep it as updated as possible as I build Kirin.


## Roadmap

- Bitboard board representation ✅
- Pre-calculated attack tables ✅
- Magic bitboards ✅
- Encoding moves as integers
- Copy/make approach for making moves
- Negamax search with alpha beta pruning
- PV/killer/history move ordering
- Iterative deepening
- PVS (Principle Variation Search)
- LMR (Late Move Reduction)
- NMP (Null Move Pruning)
- Razoring
- Evaluation pruning / static null move pruning
- Transposition table (up to 128MB)
- PURE Stockfish NNUE evaluation + 50 move rule penalty
- UCI protocol

## License

[GPL v3](https://www.gnu.org/licenses/gpl-3.0.html)

## Acknowledgements
Thank you greatly to Maksim Korzh, without whom I would not have been able to write Kirin. Also, thank you to the people on the Talk Chess forum and the Chess Programming Wiki for putting together resources used in the creation of Kirin.
 - [Maksim Korzh](https://github.com/maksimKorzh)
 - [Talk Chess](https://talkchess.com/)
 - [ChessProgramming Wiki](https://www.chessprogramming.org/Main_Page)


