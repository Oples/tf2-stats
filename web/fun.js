// Buttons "enumerator"
const boxType = {
  KILL: "kill",
  CHAT: "chat",
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

  if(!list1Elem.classList.contains("h0")) {
    // if is already shown
    // Hide all
    list1Elem.classList.add('h0');
    list2Elem.classList.add('h0');
  } else {
    // Show selected
    list2Elem.classList.add('dn');
    list1Elem.classList.remove('h0', 'dn');
    list1Elem.classList.add('transition-h4');
    list2Elem.classList.add('h0');
  }
}
