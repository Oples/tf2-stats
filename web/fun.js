
// Buttons "enumerator"
const boxType = {
  KILL: "kill",
  CHAT: "chat",
}

// Filters links to player's data array index
const filterType = {
    NAME: 0,
    TEAM: 1,
    KDRATIO: 2,
    CRIT: 3,
    WEAPON: 4
}

function toggleShowBox(elemId, button_type) {
  var list1Elem = null;
  var list2Elem = null;

  // Switch buttons based on the parameter
  switch (button_type) {
    case boxType.KILL:
      list1Elem = document.getElementById("killHistory_"+elemId);
      list2Elem = document.getElementById("chatHistory_"+elemId);
      break;
    case boxType.CHAT:
      list1Elem = document.getElementById("chatHistory_"+elemId);
      list2Elem = document.getElementById("killHistory_"+elemId);
      break;
    default:
      // continue to error
      break;
  }

  if(!list1Elem.classList.contains("maxh0")) {
    // if is already shown
    // Hide all
    list1Elem.classList.add('maxh0');
    list2Elem.classList.add('maxh0');
  } else {
    // Show selected
    list2Elem.classList.add('dn');
    list1Elem.classList.remove('maxh0', 'dn');
    list1Elem.classList.add('transition-maxh4');
    list2Elem.classList.add('maxh0');
  }
}


function filterPlayersList(input, filterType) {
    let allPlayersData = [];
    // get every player's container
    let playersList = document
        .getElementById("players_list")
        .getElementsByTagName("li");

    // for every player
    for (let i = 0; i < playersList.length; i++) {
        let playerData = [];
        // extract player's data to filter it after
        let playerField = playersList[i].getElementsByClassName("player_field");
        for (let x = 0; x < playerField.length; x++) {
            let singleVal = playerField[x].getElementsByTagName("label");
            // accept only readable names to filter
            if(singleVal.length > 0) {
                singleVal = singleVal[0].innerText;
            }
            else {
                singleVal = null;
            }
            playerData.push(singleVal);
        }
        allPlayersData.push({
            container: playersList[i],
            data: playerData
        });
    }
    // filter everything
    for (var i = 0; i < allPlayersData.length; i++) {
        if(allPlayersData[i].data[filterType] != null) {
            let inputUp = input.toUpperCase();
            let dataUp = allPlayersData[i].data[filterType].toUpperCase();
            // show names if filter matches or there is no filter
            if(dataUp.indexOf(inputUp) !== -1 || inputUp.length <= 0) {
                allPlayersData[i].container.classList.remove(
                    'h0', 'dn'
                );
            }
            // else hide this player's container
            else {
                allPlayersData[i].container.classList.add(
                    'h0', 'dn'
                );
            }
        }
    }
}

function createGraph(data) {
    let graph = document.getElementById("match_graph");

    let graphData = {
        legend: {
            x: 0,
            y: 0,
            text: ""
        },
        axis: {
            y: {
                enabled: true,
                grid: false,
                arrow: false,
                text: "",
                min: 0,
                max: 10
            },
            x: {
                enabled: true,
                grid: false,
                arrow: false,
                text: "",
                min: 0,
                max: 10
            }
        },
        data: [
            {
                x: 0,
                y: 0,
                text: "",
                value: ""
            },
        ]
    }

    // TODO: add functionality
}
