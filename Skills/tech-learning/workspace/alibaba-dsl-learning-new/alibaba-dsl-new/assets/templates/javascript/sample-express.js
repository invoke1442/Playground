const express = require("express");
const escapeHtml = require("escape-html");

const app = express();

app.get("/vulnerable", (req, res) => {
  res.send(req.query.name);
});

app.get("/safe", (req, res) => {
  res.send(escapeHtml(req.query.name));
});
