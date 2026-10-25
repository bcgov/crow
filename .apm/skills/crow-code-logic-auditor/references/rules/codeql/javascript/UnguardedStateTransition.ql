/**
 * @name Remote input written to a lifecycle state field without a transition guard
 * @description A request value is written to a status/state/stage property (directly or in an
 *              ORM update payload) without first passing through a transition validator, or where
 *              the transition validator inspected a different entity (wrong-object bypass).
 *              A client can jump the entity to an unauthorized state.
 * @kind path-problem
 * @problem.severity warning
 * @precision medium
 * @id code-logic-auditor/js/unguarded-state-transition
 * @tags security external/cwe/cwe-841 classification/FSM-BYPASS
 */

import javascript

/** A call to a transition validator, e.g. `canTransition(from, to)`. Adjust the regex. */
class TransitionGuard extends DataFlow::CallNode {
  TransitionGuard() {
    this.getCalleeName().regexpMatch("(?i).*(isValidTransition|canTransition|validateTransition|assertTransition|validateState).*")
  }

  /** The target state value (typically argument 1 or 0) is guarded on the true-branch. */
  predicate blocksExpr(boolean outcome, Expr e) {
    outcome = true and e = this.getAnArgument().asExpr()
  }
}

/**
 * Holds if `e1` and `e2` refer to demonstrably different entities (local variables or property paths like this.order / req.order).
 */
predicate entitiesDiffer(Expr e1, Expr e2) {
  // Case 1: Distinct local variables
  exists(VarAccess v1, VarAccess v2 | v1 = e1 and v2 = e2 |
    v1.getVariable() != v2.getVariable()
  )
  or
  // Case 2: Distinct properties (e.g. req.orderA vs req.orderB, or this.orderA vs this.orderB)
  exists(PropAccess p1, PropAccess p2 | p1 = e1 and p2 = e2 |
    p1.getPropertyName() != p2.getPropertyName() or
    entitiesDiffer(p1.getBase(), p2.getBase())
  )
  or
  // Case 3: Mixed access types (local variable vs property access)
  (e1 instanceof VarAccess and e2 instanceof PropAccess) or
  (e1 instanceof PropAccess and e2 instanceof VarAccess)
}

/**
 * Holds if `guard` validates variable `stateVar` specifically against `checkedEntity`
 * (e.g., `canTransition(orderA.status, next)` or `canTransition(req.orderA.status, next)`).
 */
predicate guardChecksEntityExpr(TransitionGuard guard, Expr checkedEntity, Variable stateVar) {
  exists(VarAccess stateAccess |
    stateAccess = guard.getAnArgument().asExpr() and
    stateVar = stateAccess.getVariable()
  ) and
  exists(PropAccess pa |
    pa = guard.getAnArgument().asExpr() and
    checkedEntity = pa.getBase()
  )
}

/**
 * Holds if `w` writes a variable `stateVar` to `targetEntity.status`, where an enclosing `TransitionGuard`
 * validated `stateVar` against a DIFFERENT entity `checkedEntity`.
 */
predicate isWrongObjectBypass(DataFlow::PropWrite w) {
  exists(TransitionGuard g, Expr checkedEntity, Expr targetEntity, VarAccess writtenAccess, Variable stateVar |
    writtenAccess = w.getRhs().asExpr() and
    stateVar = writtenAccess.getVariable() and
    guardChecksEntityExpr(g, checkedEntity, stateVar) and
    targetEntity = w.getBase().asExpr() and
    entitiesDiffer(checkedEntity, targetEntity)
  )
}

module StateTransitionConfig implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { n instanceof RemoteFlowSource }

  predicate isSink(DataFlow::Node n) {
    exists(DataFlow::PropWrite w |
      w.getPropertyName().regexpMatch("(?i)(status|state|stage|phase|lifecycle)") and
      n = w.getRhs()
    )
  }

  predicate isBarrier(DataFlow::Node n) {
    n = DataFlow::MakeBarrierGuard<TransitionGuard>::getABarrierNode() and
    not exists(DataFlow::PropWrite w | isWrongObjectBypass(w) and n = w.getRhs())
  }
}

module StateTransitionFlow = TaintTracking::Global<StateTransitionConfig>;

import StateTransitionFlow::PathGraph

from StateTransitionFlow::PathNode source, StateTransitionFlow::PathNode sink
where StateTransitionFlow::flowPath(source, sink)
select sink.getNode(), source, sink,
  "Lifecycle state is set from $@ without a valid entity transition guard.", source.getNode(), "remote input"
