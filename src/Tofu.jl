module Tofu

import REPL

function __init__()
    try
        REPL.REPLCompletions.latex_symbols["\\tofu"] = "◻"
    catch err
        @error "Incompatible REPL module disabling LaTeX command `\\tofu`" err
    end
end

end # module
