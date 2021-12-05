# TF2 Stats

## Installation

**1. Library**<br/>
  Open the Steam launcher and go to your LIBRARY

  <img src="docs/tf2-menu2.png" style="width:24rem;">

<br/><br/>
**2. Properties**<br/>
   add `-condebug` to the launch parameters<br/><br/>
  <img src="docs/tf2-properties.png" style="max-width:48em;width:100%;">


## Execute

**3. Requirements**

To be able to execute the project the following dependencies
must be installed.

```bash
nimble install regex
nimble install ws
nimble install norm # (W.I.P. optional)
nimble install nigui # (GUI requirement)
```

**4. Compile & Execute**

CLI application

```bash
nim c -d:release -d:strip --opt:speed -r src/main
```

GUI Instance

```bash
nim c -d:release -d:strip --opt:speed --app:gui -r src/main
```


**4.1 Development**

To run a quick test execute the following command instead
```bash
nim c -r src/web_server
```

then open http://localhost:9844

## Dependencies
> - [nimble regex](https://github.com/nitely/nim-regex)
> - [nimble ws](https://github.com/treeform/ws)
<!-- - [nimble norm](https://github.com/moigagoo/norm) W.I.P. -->
> - [nimble nigui (optional)](https://nimble.directory/pkg/nigui)
> - [JQuery js](https://jquery.com/)
> - [Toastr js](https://github.com/CodeSeven/toastr)
> - [Tachyons css](https://github.com/tachyons-css/tachyons/)
> - [Glider js](https://github.com/NickPiscitelli/Glider.js)
> - [Chart.js](https://github.com/chartjs/Chart.js)
