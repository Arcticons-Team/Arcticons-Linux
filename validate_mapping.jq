def valid_string:
	test("^[^\\s]+$");
def valid_value:
	type == "array" and all(. | valid_string);
def valid_input:
    type == "object" and (
        to_entries | all(
            (.key | valid_string) and (.value | valid_value)
        )
    );
. | if valid_input then 
        "mapping.yaml is valid"
    else
        "mapping.yaml is not valid" | halt_error(1)
    end