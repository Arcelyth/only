package parse

// https://dom.spec.whatwg.org/#interface-event
Event :: struct {
    type: string,
    target: ^Event_Target,
    src_element: ^Event_Target,  // legacy
    current_target: ^Event_Target,    
    composed_path: []Event_Target,
    event_phase: Event_Phase,
    cancel_bubble: bool,    // legacy
    bubbles: bool,
    cancelable: bool,
    return_value: bool, // legacy
    default_prevented: bool,
    composed: bool,
    is_trusted: bool,
    time_stamp: DOM_High_Res_Time_Stamp,
}

DOM_High_Res_Time_Stamp :: f64

// https://dom.spec.whatwg.org/#interface-eventtarget
Event_Target :: struct {}

Event_Phase :: enum {
    None_Phase,
    Capturing_Phase,
    At_Target,
    Bubbling_Phase,
}

Event_Handler_Proc :: proc(event: ^Event, user_data: rawptr) -> bool

Event_Handler :: struct {
	handler: Event_Handler_Proc,
	user_data: rawptr,
}
