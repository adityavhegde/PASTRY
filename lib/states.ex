defmodule Utils do
    @list ["A","B","C","D","E","F","1","2","3","4","5","6","7","8","9","0"]
    def perm_rep(key, 0) do
        key
    end
    def perm_rep(suffix, length) do
        newSuffix = Enum.random(@list)<>suffix
        perm_rep(newSuffix, length-1)
    end
    #First function to be called to start with a random character from the list. 
    #Then call perm_rep(list, suffix, length, leadingZeros, parent) to continue building suffix
    def perm_rep(length) do
        suffix = Enum.random(@list)
        perm_rep(suffix, length-1)
    end
end