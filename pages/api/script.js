export default function handler(req, res) {
    res.setHeader('Content-Type', 'text/plain');

    // Get the Place ID sent from the Roblox loader
    const placeId = req.query.placeid;

    // Map your Roblox Place IDs to your game scripts
    const scripts = {
        // 1. Break a Brainrot Egg!
        "119271610514030": `
            print("Loaded Break a Brainrot Egg!")
            -- Put your Break a Brainrot Egg script code here
        `,

        // 2. Steal Anime Eggs
        "96727061242653": `
            print("Loaded Steal Anime Eggs!")
            -- Put your Steal Anime Eggs script code here
        `,

        // 3. +1 Cut Grass Adventure
        "90086669327265": `
            print("Loaded +1 Cut Grass Adventure!")
            -- Put your +1 Cut Grass Adventure script code here
        `,

        // 4. Steal From The Rich!
        "120475074479690": `
            print("Loaded Steal From The Rich!")
            -- Put your Steal From The Rich script code here
        `,

        // Fallback / Default script if game isn't registered
        "default": `
            game.StarterGui:SetCore("SendNotification", {
                Title = "Jenicakes Hub",
                Text = "This game is not supported!",
                Duration = 5
            })
        `
    };

    // Pick the script based on the Place ID, or use default if not found
    const targetScript = scripts[placeId] || scripts["default"];
    return res.status(200).send(targetScript);
}

