# _multicd: the expansion for the dotdot abbreviation in config.fish, from
# fish's documentation. fish calls it with the dots you typed, for example
# `...`, and replaces them with what it prints: one ../ for each dot after the
# first (`cd ../../`). string length counts the dots, math subtracts one, and
# string repeat repeats ../ that many times.
function _multicd --description 'Expand .. ... .... into cd ../ ../../ ../../../'
    echo cd (string repeat --count (math (string length -- $argv[1]) - 1) ../)
end
