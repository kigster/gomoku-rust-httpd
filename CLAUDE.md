d This is a Rust Version of the Gomoku HTTPD Daemon 

There is a directory one level above: gomoku-multi-mode-monorepo/ that contains gomoku-c directory. This directory produces ./gomoku binary for terminal TUI play, and gomoku-httpd — a daemion that binds to a port and listens on incoming requests. The libraries for JSON and HTTPD handling are in gomoku-c/vendor

## Explicit Perissions

You are to ensure this Rust project:

1. follows latest Rust conventions ande versions
2. automaically upgrades everything when we are behind
3. can use event httpd library already written
4. Can use JSON parsing library and accepts and generates identical JSON to the gomoku-c
5. Has colorful line logging library and prints INFO logs 2-3 lines per request, 5-9 in debug level
6. can handle more than one request at a time, by creating partitioned set of games and boards, and all 
   computations as they are completely independent of each other.

This binary should have a rich CLI interface, which offers both short and long version of the flags. Ideally
help screen's section names are in bold cyan, regular text is normal font, and any command or example is bold
yellow. 

The binary should auto-detect number of CPU cores available and limit it's concurrency to that number.

`gomoku-rust-httpd` should ideally accept the same CLI arguments as it's C counter part, and it's JSON should be exactly the same to accept and to send back to.

## Play Algorithm & Evaluation Function

You have two options for creating the algorithm that decides the next move:

1. copy the C code and use unit tests to ensire their correctness. That's the most sane option.
2. read the PDFs in the folder /doc and deep-think your own strategy for playig this game (you know the rules) and start by creating the detailed plan on how to execute, and store it in doc/execution-plan.md. Make sure every feature has an automated test coverage.
  * Start a sub-agent that will read the plan and become the Orchestrator: it will identify if any operations are parallelizeable  and if so it would launch a sub-agent for each task. Eventually needs to go through all of the tasks. 

  * Copy executable `gomoku-http-client` from ../gomoku-multi-mode-monorepo/bin/ directory into our ./bin directory, and then you can create a shell-based integration test which starts the daemon, and then starts two thest clients pointed at the same daemon. They will start playing the game until one of them wins or a draw hapens.

Make sure that in any case executable `gomoku-rust-httpd` is installed into the `/bin` folder when `just build` is ran, and `just ci` runs all the checks. Copy `lefthook.yml` from the gomoku monorepo and update it for linting and formatting with rust commands. Copy Brew file and specify only extenal Rust dependencies or tools absolutely necessary. 

Document the entire journey in doc/step-NN-name-of-the-step.md that each sub-agent should create only one of. Each should contain a section on what to do next, that each new subagent reads, given the documents.

Work on this in a loop until the binary builds, the tests coverage is over 90%, justfile has most of the important commands to build, run, test two clients against one binary, etc. 

And in the very end write a comprehensive README.md intended first on the user of the binary (opeerations), and the second part on developing the algorithm further.

The actual algorithm that plays the game can copy C's algorithm or come up with something better based on reading the gomoku-c, or  Create a Rust project in the gomoku-rust folder and start porting the gomoku-httpd daemon to Rust please, using most modern Rust constructs and libraries.
