function initFB() {
  $.ajaxSetup({ cache: true });
  FB.init({
    appId: '477217085762255',
    version: 'v2.3'
  });
}

function fbLogin(cb) {
  FB.getLoginStatus(function(response) {
    if (response.status === 'connected') {
      cb();
    } else {
      FB.login(function(response) {
        if (response.status === 'connected') {
          cb();
        }
      });
    }
  });
}

function getFBUID(cb) {
  FB.api('/me', function(response) {
    cb(response.id);
  });
}

function buildMap(uid) {
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
        user: uid,
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
      user: uid
    }));
  };

  // Update the map with suggested countries.
  ws.onmessage = function(message) {
    console.log(message);
    msg = JSON.parse(message.data);
    if (msg.action == "country_clicked") {
      console.log(mapObj.series.regions[0]);
      if ($.isEmptyObject(msg.rankings)) {
        mapObj.series.regions[0].clear();
      } else {
        mapObj.series.regions[0].setValues(msg.rankings);
      }
    } else if (msg.action == "get_selected") {
      mapObj.setSelectedRegions(msg.selected);
    }
  };
}

initFB();
fbLogin(function() { getFBUID(buildMap); });
