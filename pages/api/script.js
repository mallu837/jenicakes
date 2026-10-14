export default function handler(req, res) {
    res.setHeader('Content-Type', 'text/plain');

    const placeId = req.query.placeid;

    // Map your Place IDs directly to the file names in your scripts/ folder
    const files = {
        "119271610514030": "breakabrainrotegg.lua",
        "96727061242653": "stealanimeeggs.lua",
        "90086669327265": "+1cutgrassadventure.lua",
        "120475074479690": "stealfromtherich.lua"
    };

    const fileName = files[placeId];

    if (!fileName) {
        return res.status(200).send('warn("[Jenicakes Hub] This game is not supported!")');
    }

    // Fetches the exact Lua file from your GitHub scripts folder
    return fetch(`https://raw.githubusercontent.com/mallu837/jenicakes/main/scripts/${fileName}`)
        .then(response => response.text())
        .then(scriptText => res.status(200).send(scriptText))
        .catch(() => res.status(500).send('warn("[Jenicakes Hub] Failed to load script file.")'));
}
