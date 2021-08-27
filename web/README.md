# Web Service

## Dta
### log

### kill
```json
{
  "kill": {
    "time": null,
    "actor": {
      "name" : "Op",
      "altSide" : false,
      "weapon" : "boom",
      "crit" : true
    },
    "target": {
      "name" : "Op",
      "altSide" : false
    }
  }
}
```

```json

{
  "match": {
    "time": null,
    "ip" : "127.0.0.1",
    "map" : "ctf_hydro",
    "maxPlayers" : 123,
  }
}
```
Change
```json
{
  "match" : {
    "sideSwitch" : true
  }
}
```

```json
{
  "chat" : {
    "specatator" : false,
    "dead" : true,
    "team" : false,
    "name" : "Op",
    "text" : "HEAVY IS DEAD!"
  }
}
```

## Ideas
### Tokens
progressive id's that launch a session and onNewLog update/add
