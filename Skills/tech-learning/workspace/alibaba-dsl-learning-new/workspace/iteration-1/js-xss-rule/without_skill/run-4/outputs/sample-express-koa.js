const express = require("express");
const Koa = require("koa");
const escapeHtml = require("escape-html");

const app = express();
app.use(express.json());

app.get("/express-query-vulnerable", (req, res) => {
    res.send(req.query.name);
});

app.post("/express-body-vulnerable", (req, res) => {
    res.write(req.body.comment);
});

app.get("/express-safe", (req, res) => {
    res.send(escapeHtml(req.query.name));
});

const koa = new Koa();

koa.use(async (ctx) => {
    if (ctx.path === "/koa-body-vulnerable") {
        ctx.body = ctx.request.body.message;
        return;
    }

    if (ctx.path === "/koa-body-safe") {
        ctx.body = escapeHtml(ctx.request.body.message);
    }
});
