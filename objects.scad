
PARENT_KEY = ":";
PROPERTIES_KEY = ".";

/*
    Get a property from the object property list
 */
function get_key_value(property_list, name) =
    (name == PROPERTIES_KEY)
        ? property_list
        : [ for (pair = property_list) if (pair[0] == name) pair ];
//
//function get_property_recursive(property_list, parent, name) =
//    let (kv = get_key_value(property_list, name))
//    (kv != undef)
//        ? kv[0]
//        : (parent != undef) ? parent(name) : undef;
//
//function object(type, parent=undef, properties=[]) =
//    let(props = [["type", type], [PARENT_KEY, super_class]])
//    function (name) get_property_recursive(props, parent, name);
//
//function define_animal(sound="purr") =
//    object("animal", super_class=object, [["sound",sound]]);


function property_list(values) =
    let (count = len(values)/2)
    let (list = [ for (i = [0:(count-1)]) [values[i*2], values[i*2+1]] ])
    function (key) [ for (pair = list) if (pair[0] == key) pair[0] ][0];

values = ["type", "cat", "size", 10];
c = len(values)/2;
p = [ for (i = [0:(c-1)]) [values[i*2], values[i*2+1]] ];
v = [ for (pair = p) if (pair[0] == "type") pair[0] ][0];
echo(c=c, p=p, v=v);

//function define_bird(type="bird", color=undef) =
//    let(props = concat(define_animal(type=type, sound="chirp")(undef), [["color", color]]))
//    function (key) get(props, key);

//cat = define_animal();
//dog = define_animal(type="dog", sound="woof");
//bird = define_bird(color="blue");
///echo(type=cat("type"), sound=cat("sound"), color=cat("color"));
//echo(type=dog("type"), sound=dog("sound"));
//echo(type=bird("type"), sound=bird("sound"), color=bird("color"));
cat = property_list(["type", "cat", "size", 10]);
echo(type=cat("type"), size=cat("size"), color=cat("color"));
