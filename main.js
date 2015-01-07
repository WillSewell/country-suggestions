// Used to identify a user. Claimed to have around 97% accuracy
var fingerprint = new Fingerprint({canvas: true}).get();

var ws = new WebSocket("ws://localhost:8081");

// The initial map configuration
var mapConf = {
  regionsSelectable: true,
  backgroundColor: '#204975',
  regionStyle: {
    selected: {
      fill: '#B50252'
    }
  },
  series: {
    regions: [{
      attribute: 'fill',
      scale: ['#FFFFFF', '#02B565'],
      //scale: ['#FFFFFF', '#000000'],
      // normalizeFunction: 'polynomial',
      min: 0,
      max: 1
    }]
  },
  // Send the clicked region to the server
  onRegionClick: function(event, code) {
    var mapObj = $('#world-map').vectorMap('get', 'mapObject');
    ws.send(JSON.stringify({
      action: "country_clicked",
      user: fingerprint,
      country: code,
      isSelected: mapObj.getSelectedRegions().indexOf(code) == -1
    }));
  }
};

// Attach the map to the DOM
$('#world-map').vectorMap(mapConf);

// Get a reference to the map object for updates
var mapObj = $('#world-map').vectorMap('get', 'mapObject');

// Load any previously selected countries
ws.onopen = function() {
  ws.send(JSON.stringify({
    action: "get_selected",
    user: fingerprint
  }));
};

// Update the map with suggested countries.
ws.onmessage = function(message) {
  console.log(message);
  msg = JSON.parse(message.data);
  if (msg.action == "country_clicked") {
    mapObj.series.regions[0].setValues(msg.rankings);
  } else if (msg.action == "get_selected") {
    mapObj.setSelectedRegions(msg.selected);
  }
};
