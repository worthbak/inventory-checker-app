# inventory-checker-app
A macOS app for checking Apple Store inventory. 

Read more here: https://worthbak.github.io/inventory-checker-app/

View development status on the project board here: [InventoryWatch Work](https://github.com/users/worthbak/projects/1/views/4?layout=board)

# Generating iPhone model number JSON

Run the following in the Chrome console while viewing an iPhone purchase page:

```
temp = {}; window.PRODUCT_SELECTION_BOOTSTRAP.productSelectionData.products.map((a) => { temp[`${a.basePartNumber}`] = a })
```

Useful Chrome console snippets:

```
temp = {}; window.PRODUCT_SELECTION_BOOTSTRAP.productSelectionData.products.map((a) => { temp[`${a.basePartNumber}`] = a })

const mapToName = (familyType) => {
	let rv = {};
	rv = Object.entries(temp)
	.filter(([key, value]) => value.familyType === familyType)
	.reduce((acc, next) => {
			var value = next[1];
			return {
				...acc,
				[value.partNumber]: `iPhone 13 Pro Max ${value.dimensionCapacity} ${value.dimensionColor}`
			}
	}, {}
	);
	return JSON.stringify(rv);
}


```