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
  var searchInput = document.getElementById("rule-search");

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
  var indexRows = toArray(document.querySelectorAll(".rule-index tr[data-rule-id]"));
  var inputs = toArray(form.querySelectorAll("input[type=checkbox][data-facet]"));
  var toggles = toArray(document.querySelectorAll(".reasons-toggle"));
  var ruleNavigationLinks = toArray(document.querySelectorAll(
    ".rule-index a[href^='#rule-'], .diagram__rules a[href^='#rule-']"
  ));
  var disclosureDetails = toArray(document.querySelectorAll("details"));
  var totalCount = cards.length;
  var printDisclosureState = null;

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

  function matchesSearch(card, query) {
    if (!query) {
      return true;
    }
    return card.textContent.toLowerCase().indexOf(query) !== -1;
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
    var query = searchInput ? searchInput.value.trim().toLowerCase() : "";
    var activeElement = document.activeElement;
    var focusWasHidden = false;
    var visibleCount = 0;
    var index;
    var card;
    var matched;
    var visibleRuleIds = {};

    for (index = 0; index < cards.length; index += 1) {
      card = cards[index];
      matched = matchesSelection(card, selection.groups) && matchesSearch(card, query);
      if (!matched && activeElement && card.contains(activeElement)) {
        focusWasHidden = true;
      }
      card.hidden = !matched;
      visibleRuleIds[card.getAttribute("data-rule-id")] = matched;
      if (matched) {
        visibleCount += 1;
        updateReasons(card, selection.selected);
      }
    }
    for (index = 0; index < indexRows.length; index += 1) {
      indexRows[index].hidden =
        !visibleRuleIds[indexRows[index].getAttribute("data-rule-id")];
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

  function openDirectDisclosure(section) {
    var child = section.firstElementChild;
    if (section.tagName && section.tagName.toLowerCase() === "details") {
      section.open = true;
      return;
    }
    while (child) {
      if (child.tagName && child.tagName.toLowerCase() === "details") {
        child.open = true;
        return;
      }
      child = child.nextElementSibling;
    }
  }

  function openSectionFromHash() {
    var hash = window.location.hash;
    var section;
    var current;
    if (!hash || hash.length < 2) {
      return;
    }
    section = document.getElementById(hash.substring(1));
    if (!section) {
      return;
    }
    openDirectDisclosure(section);
    current = section;
    while (current && current !== document) {
      if (current.tagName && current.tagName.toLowerCase() === "details") {
        current.open = true;
      }
      current = current.parentElement;
    }
  }

  function clearFilters() {
    var index;
    for (index = 0; index < inputs.length; index += 1) {
      inputs[index].checked = false;
    }
    if (searchInput) {
      searchInput.value = "";
    }
    applyFilter();
  }

  function bindRuleNavigation(link) {
    link.addEventListener("click", function (event) {
      var href = link.getAttribute("href");
      var target = href ? document.getElementById(href.substring(1)) : null;
      if (!target || !target.hidden) {
        return;
      }
      event.preventDefault();
      clearFilters();
      window.location.hash = target.id;
      openSectionFromHash();
      target.focus();
    });
  }

  var toggleIndex;
  for (toggleIndex = 0; toggleIndex < toggles.length; toggleIndex += 1) {
    bindToggle(toggles[toggleIndex]);
  }
  for (toggleIndex = 0; toggleIndex < ruleNavigationLinks.length; toggleIndex += 1) {
    bindRuleNavigation(ruleNavigationLinks[toggleIndex]);
  }

  form.hidden = false;
  window.addEventListener("hashchange", openSectionFromHash);
  form.addEventListener("change", applyFilter);
  if (searchInput) {
    searchInput.addEventListener("input", applyFilter);
  }
  form.addEventListener("reset", function () {
    if (searchInput) {
      searchInput.value = "";
    }
    window.setTimeout(applyFilter, 0);
  });

  window.addEventListener("beforeprint", function () {
    printDisclosureState = [];
    for (var detailsIndex = 0; detailsIndex < disclosureDetails.length; detailsIndex += 1) {
      printDisclosureState.push(disclosureDetails[detailsIndex].open);
      disclosureDetails[detailsIndex].open = true;
    }
    for (var index = 0; index < cards.length; index += 1) {
      cards[index].hidden = false;
    }
  });
  window.addEventListener("afterprint", function () {
    if (printDisclosureState) {
      for (var detailsIndex = 0; detailsIndex < disclosureDetails.length; detailsIndex += 1) {
        disclosureDetails[detailsIndex].open = printDisclosureState[detailsIndex];
      }
      printDisclosureState = null;
    }
    applyFilter();
  });

  openSectionFromHash();
  applyFilter();
})();
