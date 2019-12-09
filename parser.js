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
            for (i = 0; currentNode && i < currentNode.length; i += 1) {
                currentChild = currentNode[i];
                findNodes(currentChild, result);
            }
        } else {
            Object.keys(currentNode).forEach( label => {
                currentChild = currentNode[label];
                findNodes(currentChild, result);
            });
        }
    }
    return result;
}

function computeStat(analyzes) {
    let result = {}
    for (let stat of analyzes) {
        Object.keys(stat).forEach( label => {
            result[label] = (result[label]) ? result[label] + stat[label] : stat[label];
        });
    }
    analyzes.push(result);
}

function processFile(name, content) {

    let input = {
        language: 'Solidity',
        sources: {
            [name]: {
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
    if (!output["sources"][name]) {
        return {[name] : "not compiled"};
    }
    let ast = output["sources"][name]["ast"];
    
    return findNodes(ast, {});
}

let files = fs.readdirSync('./contracts/');
let analyzes = [];
files.forEach(name => {
    let content = fs.readFileSync("./contracts/" + name, 'utf8')
    analyzes.push(processFile(name, content));
})
computeStat(analyzes);
console.log(JSON.stringify(analyzes, null, 2))




