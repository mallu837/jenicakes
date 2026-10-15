
module.exports = async (req, res) => {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Content-Type', 'text/plain; charset=utf-8');

    const placeId = String(req.query.placeid || "").trim();

    const files = {
        "119271610514030": "breakabrainrotegg.lua",
        "96727061242653": "stealanimeeggs.lua",
        "90086669327265": "+1cutgrassadventure.lua",
        "120475074479690": "stealfromtherich.lua",
        "142823291": "mm2.lua"
    };

    const fileName = files[placeId];

    if (!fileName) {
        return res.status(200).send(
            `warn("[Jenicakes Hub] Game not supported! Place ID: ${placeId}")`
        );
    }

    try {
        const rawUrl = `https://raw.githubusercontent.com/mallu837/jenicakes/main/scripts/${fileName}`;
        const response = await fetch(rawUrl);

        if (!response.ok) {
            return res.status(200).send(
                `warn("[Jenicakes Hub] Script file not found: ${fileName}")`
            );
        }

        const scriptText = await response.text();
        return res.status(200).send(scriptText);
    } catch (err) {
        return res.status(200).send(
            `warn("[Jenicakes Hub] Error: ${err.message}")`
        );
    }
};
