// RUN: %target-swift-frontend %s -emit-sil -o - | %FileCheck %s
// REQUIRES: objc_interop

import Foundation

@objc
public protocol DangerousEscaper {
  @objc
  func malicious(_ mayActuallyEscape: () -> ())
}

// CHECK: sil @$S27closure_lifetime_fixup_objc19couldActuallyEscapeyyyyc_AA16DangerousEscaper_ptF : $@convention(thin) (@guaranteed @callee_guaranteed () -> (), @guaranteed DangerousEscaper) -> () {
// CHECK: bb0([[ARG:%.*]] : $@callee_guaranteed () -> (), [[SELF:%.*]] : $DangerousEscaper):
// CHECK:   [[OE:%.*]] = open_existential_ref [[SELF]]

// Copy (1).
// CHECK:   strong_retain [[ARG]] : $@callee_guaranteed () -> ()

// Extend the lifetime to the end of this function (2).
// CHECK:   strong_retain [[ARG]] : $@callee_guaranteed () -> ()
// CHECK:   [[OPT_CLOSURE:%.*]] = enum $Optional<@callee_guaranteed () -> ()>, #Optional.some!enumelt.1, [[ARG]] : $@callee_guaranteed () -> ()

// CHECK:   [[NE:%.*]] = convert_escape_to_noescape [[ARG]] : $@callee_guaranteed () -> () to $@noescape @callee_guaranteed () -> ()
// CHECK:   [[WITHOUT_ACTUALLY_ESCAPING_THUNK:%.*]] = function_ref @$SIg_Ieg_TR : $@convention(thin) (@noescape @callee_guaranteed () -> ()) -> ()
// CHECK:   [[C:%.*]] = partial_apply [callee_guaranteed] [[WITHOUT_ACTUALLY_ESCAPING_THUNK]]([[NE]]) : $@convention(thin) (@noescape @callee_guaranteed () -> ()) -> ()

// Sentinel without actually escaping closure (3).
// CHECK:   [[SENTINEL:%.*]] = mark_dependence [[C]] : $@callee_guaranteed () -> () on [[NE]] : $@noescape @callee_guaranteed () -> ()

// Copy of sentinel (4).
// CHECK:   strong_retain [[SENTINEL]] : $@callee_guaranteed () -> ()
// CHECK:   [[BLOCK_STORAGE:%.*]] = alloc_stack $@block_storage @callee_guaranteed () -> ()
// CHECK:   [[CLOSURE_ADDR:%.*]] = project_block_storage [[BLOCK_STORAGE]] : $*@block_storage @callee_guaranteed () -> ()
// CHECK:   store [[SENTINEL]] to [[CLOSURE_ADDR]] : $*@callee_guaranteed () -> ()
// CHECK:   [[BLOCK_INVOKE:%.*]] = function_ref @$SIeg_IyB_TR : $@convention(c) (@inout_aliasable @block_storage @callee_guaranteed () -> ()) -> ()
// CHECK:   [[BLOCK:%.*]] = init_block_storage_header [[BLOCK_STORAGE]] : $*@block_storage @callee_guaranteed () -> (), invoke [[BLOCK_INVOKE]] : $@convention(c) (@inout_aliasable @block_storage @callee_guaranteed () -> ()) -> (), type $@convention(block) @noescape () -> ()

// Optional sentinel (4).
// CHECK:   [[OPT_SENTINEL:%.*]] = enum $Optional<@callee_guaranteed () -> ()>, #Optional.some!enumelt.1, [[SENTINEL]] : $@callee_guaranteed () -> ()

// Copy of sentinel closure (5).
// CHECK:   [[BLOCK_COPY:%.*]] = copy_block [[BLOCK]] : $@convention(block) @noescape () -> ()

// Release of sentinel closure (3).
// CHECK:   destroy_addr [[CLOSURE_ADDR]] : $*@callee_guaranteed () -> ()
// CHECK:   dealloc_stack [[BLOCK_STORAGE]] : $*@block_storage @callee_guaranteed () -> ()

// Release of closure copy (1).
// CHECK:   strong_release %0 : $@callee_guaranteed () -> ()
// CHECK:   [[METH:%.*]] = objc_method [[OE]] : $@opened("{{.*}}") DangerousEscaper, #DangerousEscaper.malicious!1.foreign : <Self where Self : DangerousEscaper> (Self) -> (() -> ()) -> (), $@convention(objc_method) <τ_0_0 where τ_0_0 : DangerousEscaper> (@convention(block) @noescape () -> (), τ_0_0) -> ()
// CHECK:   apply [[METH]]<@opened("{{.*}}") DangerousEscaper>([[BLOCK_COPY]], [[OE]]) : $@convention(objc_method) <τ_0_0 where τ_0_0 : DangerousEscaper> (@convention(block) @noescape () -> (), τ_0_0) -> ()

// Release sentinel closure copy (5).
// CHECK:   strong_release [[BLOCK_COPY]] : $@convention(block) @noescape () -> ()
// CHECK:   [[ESCAPED:%.*]] = is_escaping_closure [objc] [[OPT_SENTINEL]] : $Optional<@callee_guaranteed () -> ()>
// CHECK:   cond_fail [[ESCAPED]] : $Builtin.Int1

// Release of sentinel copy (4).
// CHECK:   release_value [[OPT_SENTINEL]] : $Optional<@callee_guaranteed () -> ()>

// Extendend lifetime (2).
// CHECK:   release_value [[OPT_CLOSURE]] : $Optional<@callee_guaranteed () -> ()>
// CHECK:   return

public func couldActuallyEscape(_ closure: @escaping () -> (), _ villian: DangerousEscaper) {
  villian.malicious(closure)
}
