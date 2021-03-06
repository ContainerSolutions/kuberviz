'use strict';

// HOW THIS WORKS
// The svg generated by graphviz  is fetched 10 ms after the previous round succeeded.
//
// The new result is compared with prevSVG to prevent unnecessary redraws.
// If the SVG elements changed, it destroys the SVG zoomer, but not before storing the
// zoom level and panning (x,y coords). The SVG elements are recreated
// and the zoom level and panning is restored.

var prevSVG = null;
var zoomer = null

function hasChanged(newHtml) {
  if (prevSVG == null) {
    prevSVG = newHtml;
    return true;
  }

  if (newHtml == prevSVG) {
    return false;
  } else {
    prevSVG = newHtml;
    return true;
  }
}

function focusOnThing(kind, uid) {
  console.log(kind, uid);
  switch(kind) {
    case "pod": focusPod(uid); break;
    default: console.log("displaying info of ", kind, "not handled");
  }
}

function syntaxHighlight(object) {
    var json = JSON.stringify(object, undefined, 4);
    json = json.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
    var result = json.replace(/("(\\u[a-zA-Z0-9]{4}|\\[^u]|[^\\"])*"(\s*:)?|\b(true|false|null)\b|-?\d+(?:\.\d*)?(?:[eE][+\-]?\d+)?)/g, function (match) {
        var cls = 'number';
        if (/^"/.test(match)) {
            if (/:$/.test(match)) {
                cls = 'key';
            } else {
                cls = 'string';
            }
        } else if (/true|false/.test(match)) {
            cls = 'boolean';
        } else if (/null/.test(match)) {
            cls = 'null';
        }
        return '<span class="' + cls + '">' + match + '</span>';
    });

  return "<pre>" + result + "</pre>";
}

function focusPod(uid) {
  var pod = info.pods.find(function(pod) { return pod["uid"] == uid });
  var html = "<h2>Pod details</h2>";
  html += "<p><b>Name</b>:" +pod.name+"</p>";
  html += "<p><button onclick='deletePod(\"" + pod.name+ "\")'+>Delete</button>";
  html += "<h3>Details</h3>";
  html += syntaxHighlight(pod);
  $("#sidebar").html(html);
}

function deletePod(name) {
  $("#sidebar").html("Deleted pod " + name);
  $.post("/delete_pod", { name: name})
}

var info = {};

function completeRedraw() {
  $.get("/graph.svg", function(data) {
    var svg = $(data.documentElement)

    if (hasChanged(svg.html())) {
      $.getJSON("/graph.json", function(graph_info) {
        info = graph_info;
      });

      var oldZoomerProps = null;
      if (zoomer) {
        oldZoomerProps = {
          pan:  zoomer.getPan(),
          zoom: zoomer.getZoom()
        };
        zoomer.destroy();
      }

      $("#viz").empty().append(svg);

      zoomer = svgPanZoom('#viz', {
        zoomEnabled: true,
        controlIconsEnabled: true,
        fit: true,
        center: true,
        customEventsHandler: {
          init: function(options){
            function updateSvgClassName(){
              options.svgElement.setAttribute('class', '' + (svgActive ? 'active':'') + (svgHovered ? ' hovered':''))
            }

            this.listeners = {
              click: function(e){
                var node = $(e.target).closest(".node")[0];
                if (node != null) {
                  var parts = node.id.split(/_(.*)/);
                  var kind = parts[0];
                  var id = parts[1].replace(/_/g, "-");
                  focusOnThing(kind,id);
                }
              }
            };

            for (var eventName in this.listeners){
              options.svgElement.addEventListener(eventName, this.listeners[eventName])
            }
          },
          destroy: function(options){
            for (var eventName in this.listeners){
              options.svgElement.removeEventListener(eventName, this.listeners[eventName])
            }
          }
        }
      });

      if (oldZoomerProps != null) {
        zoomer.zoom(oldZoomerProps.zoom)
        zoomer.pan(oldZoomerProps.pan)
      } else {
        // By default, zoom to a sensible default.
        // setTimeout is required to delegate setting
        // the zoom level until the next browser event loop;
        // I suspect that otherwise the zoomer will just overwrite it to 1.
        setTimeout(function() {
          zoomer.zoom(0.5);
        }, 0);
      }
    }

    setTimeout(completeRedraw, 100);
  });
}

$(document).ready(completeRedraw);
