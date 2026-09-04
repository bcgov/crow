/*
  Crow business-rule report behaviour.

  Progressive enhancement only: the generated HTML is complete and readable
  without this file. When it runs, it reveals the facet filter, applies AND
  across facet groups and OR within a group, keeps the visible match reasons in
  step with the selection, and announces result counts politely.

  The script never writes markup: it toggles the `hidden` property on elements
  that the renderer already produced, so no untrusted text is re-parsed as HTML.
*/
(function () {
  "use strict";

  var form = document.getElementById("facet-filter");
  var ruleList = document.getElementById("rule-list");
  var statusRegion = document.getElementById("filter-status");
  var emptyMessage = document.getElementById("no-results");

  if (!form || !ruleList || !statusRegion || !emptyMessage) {
    return;
  }

  function toArray(nodeList) {
    var items = [];
    var index;
    for (index = 0; index < nodeList.length; index += 1) {
      items.push(nodeList[index]);
    }
    return items;
  }

  var cards = toArray(ruleList.querySelectorAll(".rule-card"));
  var inputs = toArray(form.querySelectorAll("input[type=checkbox][data-facet]"));
  var toggles = toArray(document.querySelectorAll(".reasons-toggle"));
  var totalCount = cards.length;

  function getFacets(card) {
    var value = card.getAttribute("data-facets");
    if (!value) {
      return [];
    }
    return value.split(" ").filter(function (facet) {
      return facet.length > 0;
    });
  }

  function getSelection() {
    var groups = {};
    var selected = [];
    var index;
    var input;
    var groupName;
    for (index = 0; index < inputs.length; index += 1) {
      input = inputs[index];
      if (!input.checked) {
        continue;
      }
      groupName = input.getAttribute("data-group") || "";
      if (!groups[groupName]) {
        groups[groupName] = [];
      }
      groups[groupName].push(input.getAttribute("data-facet"));
      selected.push(input.getAttribute("data-facet"));
    }
    return { groups: groups, selected: selected };
  }

  function matchesSelection(card, groups) {
    var facets = getFacets(card);
    var groupNames = Object.keys(groups);
    var index;
    var groupFacets;
    var matchedInGroup;
    var facetIndex;
    for (index = 0; index < groupNames.length; index += 1) {
      groupFacets = groups[groupNames[index]];
      matchedInGroup = false;
      for (facetIndex = 0; facetIndex < groupFacets.length; facetIndex += 1) {
        if (facets.indexOf(groupFacets[facetIndex]) !== -1) {
          matchedInGroup = true;
          break;
        }
      }
      if (!matchedInGroup) {
        return false;
      }
    }
    return true;
  }

  function updateReasons(card, selected) {
    var reasons = toArray(card.querySelectorAll(".match-reason"));
    var index;
    var reason;
    for (index = 0; index < reasons.length; index += 1) {
      reason = reasons[index];
      if (selected.length === 0) {
        reason.hidden = false;
      } else {
        reason.hidden = selected.indexOf(reason.getAttribute("data-facet")) === -1;
      }
    }
  }

  function applyFilter() {
    var selection = getSelection();
    var activeElement = document.activeElement;
    var focusWasHidden = false;
    var visibleCount = 0;
    var index;
    var card;
    var matched;

    for (index = 0; index < cards.length; index += 1) {
      card = cards[index];
      matched = matchesSelection(card, selection.groups);
      if (!matched && activeElement && card.contains(activeElement)) {
        focusWasHidden = true;
      }
      card.hidden = !matched;
      if (matched) {
        visibleCount += 1;
        updateReasons(card, selection.selected);
      }
    }

    if (visibleCount === 0) {
      statusRegion.textContent =
        "No rules match the selected filters. Clear filters to show all " +
        totalCount + " rules.";
    } else {
      statusRegion.textContent =
        "Showing " + visibleCount + " of " + totalCount + " rules.";
    }
    emptyMessage.hidden = visibleCount !== 0;

    if (focusWasHidden) {
      statusRegion.focus();
    }
  }

  function bindToggle(toggle) {
    var targetId = toggle.getAttribute("aria-controls");
    var target = targetId ? document.getElementById(targetId) : null;
    if (!target) {
      return;
    }
    toggle.hidden = false;
    toggle.addEventListener("click", function () {
      var expanded = toggle.getAttribute("aria-expanded") === "true";
      toggle.setAttribute("aria-expanded", expanded ? "false" : "true");
      target.hidden = expanded;
    });
  }

  var toggleIndex;
  for (toggleIndex = 0; toggleIndex < toggles.length; toggleIndex += 1) {
    bindToggle(toggles[toggleIndex]);
  }

  form.hidden = false;
  form.addEventListener("change", applyFilter);
  form.addEventListener("reset", function () {
    window.setTimeout(applyFilter, 0);
  });

  applyFilter();
})();
