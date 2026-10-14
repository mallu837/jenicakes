export default async function handler(req, res) {
    // Enable CORS so Roblox Executors don't block the request
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');

    // Get placeid from URL query string
    const placeId = String(req.query.placeid || "").trim();

    // Mapping Place IDs to your Lua script files in scripts/
    const files = {
        "119271610514030": "breakabrainrotegg.lua",
        "96727061242653": "stealanimeeggs.lua",
        "90086669327265": "+1cutgrassadventure.lua",
        "120475074479690": "stealfromtherich.lua"
    };

    const fileName = files[placeId];

    if (!fileName) {
        return res.status(200).send(`warn("[Jenicakes Hub] Game not supported! Place ID: ${placeId}")`);
    }

    try {
        const rawUrl = `https://raw.githubusercontent.com/mallu837/jenicakes/main/scripts/${fileName}`;
        const response = await fetch(rawUrl);
        
        if (!response.ok) {
            return res.status(200).send(`warn("[Jenicakes Hub] Could not find script file: ${fileName}")`);
        }

        const scriptText = await response.text();
        return res.status(200).send(scriptText);
    } catch (err) {
        return res.status(200).send(`warn("[Jenicakes Hub] Error: ${err.message}")`);
    }
}
