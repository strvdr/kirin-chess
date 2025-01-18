
# Kirin Chess Engine
[![GPLv3 License](https://img.shields.io/badge/License-GPL%20v3-yellow.svg)](https://opensource.org/licenses/)

The original Kirin Chess Engine was written in C and the source code is available [here](https://github.com/strvdr/kirin-ce). I have since deprecated this project and am now writing the Kirin Chess Engine in Zig. 


## Authors

- [Strydr Silverberg - @strvdr](https://www.github.com/strvdr)

## Documentation

I write a weekly devlog which you can view at [strydr.net](https://strydr.net/articles). These devlogs are meant to serve as a walk through my thought process while building Kirin, as well as a limited form of documentation of the project. 

I am also working on a documentation website for Kirin, which will be available at a subdomain to my website in the coming months.

## Roadmap

- Bitboard board representation ✅
- Pre-calculated attack tables ✅
- Magic bitboards ✅
- Encoding moves as a packed struct ✅
- Copy/make approach for making moves ✅
- Pseudolegal move generation with immediate legality testing ✅
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

Also thank you to Hejsil for suggesting that I change the encoding of moves from an integer to a packed struct. This lead me down a rabbit hole of improvements and modifications. 

 - [Maksim Korzh](https://github.com/maksimKorzh)
 - [Talk Chess](https://talkchess.com/)
 - [ChessProgramming Wiki](https://www.chessprogramming.org/Main_Page)
 - [Hejsil](https://github.com/Hejsil)

