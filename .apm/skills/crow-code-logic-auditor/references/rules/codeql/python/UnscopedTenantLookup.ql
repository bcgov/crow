/**
 * @name Request-controlled value reaches an unscoped or attacker-controlled ORM lookup
 * @description A value from the request is used in an ORM lookup through the model's
 *              manager or query chain (Model.objects, _default_manager, get_object_or_404) where either:
 *              1. No tenant/org/owner keyword predicate is provided in the call, OR
 *              2. The tenant scoping keyword argument itself receives untrusted remote input.
 *              Caveat: Flagged sites represent candidate lookups requiring architecture and runtime
 *              verification; database-level PostgreSQL RLS or schema-per-tenant require separate verification.
 * @kind path-problem
 * @problem.severity warning
 * @precision medium
 * @id code-logic-auditor/python/unscoped-tenant-lookup
 * @tags security external/cwe/cwe-639 classification/TENANT-LEAK
 */

import python
import semmle.python.dataflow.new.DataFlow
import semmle.python.dataflow.new.TaintTracking
import semmle.python.dataflow.new.RemoteFlowSources

/** Keyword names that indicate candidate tenant or organizational scoping. */
bindingset[k]
predicate isScopingKeyword(string k) {
  k.regexpMatch("(?i).*(tenant|org|organi[sz]ation|company|account|owner|workspace).*")
}

/** Matches Model.objects, Model._default_manager, etc. */
bindingset[attr]
predicate isManagerAttribute(string attr) {
  attr.regexpMatch("(?i)(objects|_default_manager|all_objects)")
}

/** Recursively matches a manager attribute or a chained queryset method call. */
predicate isQuerysetOrManager(DataFlow::Node n) {
  isManagerAttribute(n.(DataFlow::AttrRead).getAttributeName())
  or
  exists(DataFlow::MethodCallNode chain |
    chain = n and
    chain.getMethodName() in ["select_related", "prefetch_related", "filter", "exclude", "all", "order_by", "only", "defer", "using"] and
    isQuerysetOrManager(chain.getObject())
  )
}

/** A call like `Model.objects.get(...)` / `.filter(...)` with no scoping keyword. */
predicate lookupMissingScopeKeyword(DataFlow::MethodCallNode call) {
  call.getMethodName() in ["get", "filter", "exclude", "get_or_create", "update_or_create"] and
  isQuerysetOrManager(call.getObject()) and
  not exists(string k | exists(call.getArgByName(k)) and isScopingKeyword(k))
}

/** A call like `get_object_or_404(Model, pk=...)` with no scoping keyword and not anchored to user relation. */
predicate getObjectOr404MissingScope(DataFlow::CallNode call) {
  call.getCalleeName() = "get_object_or_404" and
  not exists(string k | exists(call.getArgByName(k)) and isScopingKeyword(k)) and
  not exists(DataFlow::AttrRead read |
    read = call.getArg(0) and
    read.getObject().(DataFlow::AttrRead).getAttributeName() in ["user", "principal"]
  )
}

/** A call like `Model.objects.get(...)` where a scoping keyword is present. */
predicate lookupWithScopeKeyword(DataFlow::MethodCallNode call, string k) {
  call.getMethodName() in ["get", "filter", "exclude", "get_or_create", "update_or_create"] and
  isQuerysetOrManager(call.getObject()) and
  isScopingKeyword(k) and
  exists(call.getArgByName(k))
}

module UnscopedLookupConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { n instanceof RemoteFlowSource }

  predicate isSink(DataFlow::Node n) {
    // Case 1: Call lacks any scoping keyword; lookup arguments are sinks
    exists(DataFlow::MethodCallNode c | lookupMissingScopeKeyword(c) |
      n = c.getArgByName(_) or n = c.getArg(_)
    )
    or
    // Case 2: get_object_or_404 call lacking scoping keyword
    exists(DataFlow::CallNode c | getObjectOr404MissingScope(c) |
      n = c.getArgByName(_) or n = c.getArg(_)
    )
    or
    // Case 3: Scoping keyword is present, but its argument value is tainted by untrusted input
    exists(DataFlow::MethodCallNode c, string k | lookupWithScopeKeyword(c, k) |
      n = c.getArgByName(k)
    )
  }

  predicate isBarrier(DataFlow::Node n) {
    // Sanitizer barrier: Values originating from authenticated principal attributes or session claims
    exists(DataFlow::AttrRead read |
      read = n and
      (
        read.getObject().(DataFlow::AttrRead).getAttributeName() in ["user", "session", "auth"] or
        read.getAttributeName() in ["user", "session", "auth"]
      )
    )
  }
}

module UnscopedLookupFlow = TaintTracking::Global<UnscopedLookupConfig>;

import UnscopedLookupFlow::PathGraph

from UnscopedLookupFlow::PathNode source, UnscopedLookupFlow::PathNode sink
where UnscopedLookupFlow::flowPath(source, sink)
select sink.getNode(), source, sink,
  "Request-controlled $@ reaches an ORM lookup lacking verified principal tenant scoping.", source.getNode(),
  "value"
