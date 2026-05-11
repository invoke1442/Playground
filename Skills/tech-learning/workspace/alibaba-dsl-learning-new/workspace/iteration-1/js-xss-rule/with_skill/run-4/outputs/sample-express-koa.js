function escapeHtml(value) {
    return String(value)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;")
        .replace(/'/g, "&#39;");
}

function expressVulnerable(req, res) {
    res.send(req.query.name);
    res.write(req.body.comment);
}

function expressSafe(req, res) {
    res.send(escapeHtml(req.query.name));
}

async function koaVulnerable(ctx) {
    ctx.body = ctx.request.body.message;
}

async function koaSafe(ctx) {
    ctx.body = escapeHtml(ctx.request.body.message);
}

module.exports = {
    escapeHtml,
    expressVulnerable,
    expressSafe,
    koaVulnerable,
    koaSafe
};
