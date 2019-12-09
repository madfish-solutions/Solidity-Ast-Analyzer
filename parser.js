let solc = require('solc')
let fs = require('fs');

function findNodes(currentNode, result) {
    let i,
        currentChild;

    if (!currentNode) {
        return result;
    }
    if (currentNode.nodeType) {
        result[currentNode.nodeType] = (result[currentNode.nodeType]) ? (result[currentNode.nodeType] + 1) : 1;
    }
    if (typeof currentNode === 'object') {
        if (Array.isArray(currentNode)) {
            // console.log(currentNode);
            for (i = 0; currentNode && i < currentNode.length; i += 1) {
                currentChild = currentNode[i];
                findNodes(currentChild, result);
                // result.push(...newNodes);
            }
        } else {
            Object.keys(currentNode).forEach( label => {
                // console.log(currentNode);
                currentChild = currentNode[label];
                findNodes(currentChild, result);
                // result.push(...newNodes);
            });
        }
    }
    return result;
}

function processFile(name, content) {

    let input = {
        language: 'Solidity',
        sources: {
            "file.sol": {
                content: content
            }
        },
        settings: {
            outputSelection: {
                '*': {
                    '*': [ '*' ],
                    '' : ['ast']            }
            }
        }
    }
    
    let output = JSON.parse(solc.compile(JSON.stringify(input)))
    let ast = output["sources"]["file.sol"]["ast"];
    
    return findNodes(ast, {});
}

let files = fs.readdirSync('./contracts/');
let analyzes = [];
files.forEach(name => {
    let content = fs.readFileSync("./contracts/" +name, 'utf8')
    analyzes.push(processFile(name, content));
})
console.log(JSON.stringify(analyzes, null, 2))




