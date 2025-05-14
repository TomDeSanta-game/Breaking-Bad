extends Node

var id_map: Dictionary = {
	"early_meth_batch": {
		"name": "Early Methaphetamine Batch",
		"texture": null,
		"description": "A small batch of crude methamphetamine.",
		"quantity": 1
	}
}

func add_item(item_id: String, inventory_node: Node) -> void:
	if id_map.has(item_id):
		var item_data = id_map[item_id].duplicate()
		inventory_node.add_item(item_data)
		Log.info("Added item with ID: " + item_id)
	else:
		Log.warn("ID " + item_id + " not found in id_map!")
