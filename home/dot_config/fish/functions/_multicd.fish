# From fish's documentation: one ../ for each dot after the first.
function _multicd --description 'Expand .. ... .... into cd ../ ../../ ../../../'
    echo cd (string repeat --count (math (string length -- $argv[1]) - 1) ../)
end
