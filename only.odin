package only

Text :: string
AttrMap :: map[string]string

Element :: struct {
    tag_name: string,
    attrs: AttrMap,
}

NodeType :: union {
    Text, 
    Element,
}

Node :: struct {
    children: [dynamic]Node,
    type: NodeType
}

text :: proc(data: string) -> Node {
    return Node {
        children = make([dynamic]Node),
        type = data        
    }
}

elem :: proc(tag_name: string, attrs: AttrMap, children: [dynamic]Node) -> Node {
    return Node {
        children,
        Element {
            tag_name, 
            attrs
        }
    }
}

main :: proc() {
        
}
