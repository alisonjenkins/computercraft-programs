-- 5x5 footprint, 3 layers tall. Hollow shed with a single glass cell on the front.
return {
    palette = {
        [" "] = nil,                      -- air
        ["C"] = "minecraft:cobblestone",
        ["P"] = "minecraft:oak_planks",
        ["G"] = "minecraft:glass",
    },
    layers = {
        -- y = 0 (floor)
        {
            "CCCCC",
            "CPPPC",
            "CPPPC",
            "CPPPC",
            "CCCCC",
        },
        -- y = 1 (walls + window)
        {
            "CCCCC",
            "C   C",
            "C   C",
            "C   C",
            "CGCCC",
        },
        -- y = 2 (roof)
        {
            "CCCCC",
            "CPPPC",
            "CPPPC",
            "CPPPC",
            "CCCCC",
        },
    },
}
