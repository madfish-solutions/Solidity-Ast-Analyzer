let solc4 = require('solc4')
let solc5 = require('solc5')
let fs = require('fs');

function findNodes5(currentNode, result) {
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
                findNodes5(currentChild, result);
            }
        } else {
            Object.keys(currentNode).forEach( label => {
                currentChild = currentNode[label];
                findNodes5(currentChild, result);
            });
        }
    }
    return result;
}

function findNodes4(currentNode, result) {
    let i,
        currentChild;

    if (!currentNode) {
        return result;
    }
    if (currentNode.name) {
        result[currentNode.name] = (result[currentNode.name]) ? (result[currentNode.name] + 1) : 1;
    }
    if (typeof currentNode === 'object') {
        if (Array.isArray(currentNode)) {
            for (i = 0; currentNode && i < currentNode.length; i += 1) {
                currentChild = currentNode[i];
                findNodes4(currentChild, result);
            }
        } else {
            Object.keys(currentNode).forEach( label => {
                currentChild = currentNode[label];
                findNodes4(currentChild, result);
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
    let output = JSON.parse(solc5.compile(JSON.stringify(input)));
    let ast;
    if (!output["sources"][name]) {
        output = solc4.compile(content);
        if (!output["sources"][""]) {
            return {[name] : "not compiled"};
        }
        ast = output["sources"][""]["AST"];
        return findNodes4(ast, {});
    } else {
        ast = output["sources"][name]["ast"];
        return findNodes5(ast, {});
    }
    
}

let files = fs.readdirSync('./contracts/');
let analyzes = [];
files.forEach(name => {
    let content = fs.readFileSync("./contracts/" + name, 'utf8')
    analyzes.push(processFile(name, content));
})
computeStat(analyzes);
console.log(JSON.stringify(analyzes, null, 2))




