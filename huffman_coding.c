//An implementation of Huffman Coding in C
//Author: Fan Bu

#include <stdio.h>
#include <stdlib.h>

//structure for a node in the Huffman tree
typedef struct node node;
struct node{
    char character;
    int frequency;
    node *leftChild;
    node *rightChild;
};

//helper function to compare 2 nodes based on their frequencies
int compareFrequency(const void * nodeA_ptr, const void * nodeB_ptr){
    node* nodeA = *((node **) nodeA_ptr);
    node* nodeB = *((node **) nodeB_ptr);
    int aFrequency = nodeA->frequency;
    int bFrequency = nodeB->frequency;
    return aFrequency - bFrequency;
}

//function that prints the Huffman tree
void printNode(node* nodeToPrint, int depth, char code[],
               unsigned long long* totalSize){
    
    if (nodeToPrint->leftChild == NULL){
        *totalSize += nodeToPrint->frequency * depth;
        printf("character: %c, frequency: %d, at depth: %d, code: ",
               nodeToPrint->character, nodeToPrint->frequency, depth);
        for (int i = 0; i < depth; i++) {
            printf("%c", code[i]);
        }
        printf("\n");
    }else{
        code[depth] = '0';
        printNode(nodeToPrint->leftChild, depth+1, code, totalSize);
        code[depth] = '1';
        printNode(nodeToPrint->rightChild, depth+1, code, totalSize);
    }
}

//function that helps create the Huffman tree
node* newCombinedNode(node* a, node* b, node* c, node* d,
                      int* iCount, int* jStartCount){
    
    node* nodesToCompare[] = {a,b,c,d};
    
    node* minFrequencyNode = NULL;
    int i;
    for (i = 0; i < 4; i++) {
        if (nodesToCompare[i] == NULL) continue;
        if (minFrequencyNode == NULL){
            minFrequencyNode = nodesToCompare[i];
        }else if (nodesToCompare[i]->frequency < minFrequencyNode->frequency){
            minFrequencyNode = nodesToCompare[i];
        }
    }
    
    node* secondMinFrequencyNode = NULL;
    for (i = 0; i < 4; i++) {
        if (nodesToCompare[i] == NULL || nodesToCompare[i] == minFrequencyNode) continue;
        if (secondMinFrequencyNode == NULL){
            secondMinFrequencyNode = nodesToCompare[i];
        }else if (nodesToCompare[i]->frequency < secondMinFrequencyNode->frequency){
            secondMinFrequencyNode = nodesToCompare[i];
        }
    }
    
    if (minFrequencyNode == a){
        (*iCount)++;
    }else if (minFrequencyNode == c){
        (*jStartCount)++;
    }
    
    if (secondMinFrequencyNode == a || secondMinFrequencyNode == b){
        (*iCount)++;
    }else if (secondMinFrequencyNode == c|| secondMinFrequencyNode == d){
        (*jStartCount)++;
    }
    
    node* newConbinedNode = (node*) malloc(sizeof(node));
    newConbinedNode->character = 0;
    newConbinedNode->frequency = minFrequencyNode->frequency + secondMinFrequencyNode->frequency;
    newConbinedNode->leftChild = minFrequencyNode;
    newConbinedNode->rightChild = secondMinFrequencyNode;
    return newConbinedNode;
}

int main(int argc, const char * argv[]) {

    int arraySize;

    //read the number of different characters
    scanf("%d\n", &arraySize);
    node* nodes[arraySize];
    int i;

    //read the characters and their respective frequencies
    for (i = 0; i < arraySize; i++) {
        nodes[i] = (node*) malloc(sizeof(node));
        nodes[i]->leftChild = NULL;
        nodes[i]->rightChild = NULL;
        if (i == arraySize - 1){
            scanf("%c %d", &nodes[i]->character, &nodes[i]->frequency);
        }else{
            scanf("%c %d\n", &nodes[i]->character, &nodes[i]->frequency);
        }
    }

    //sort the nodes based on their frequencies
    qsort(nodes, arraySize, sizeof(node*), compareFrequency);
    
    //create the Huffman tree
    node* combinedNodes[arraySize - 1];
    for (i = 0; i < arraySize - 1; i++) {
        combinedNodes[i] = NULL;
    }
    i = 0;
    int jStart = 0;
    int jEnd = 0;
    while (jEnd < arraySize - 1){
        if (i == arraySize - 1) {
            combinedNodes[jEnd] = newCombinedNode(nodes[i], NULL,
                                                  combinedNodes[jStart], combinedNodes[jStart+1],
                                                  &i, &jStart);
        }else if (i > arraySize - 1){
            combinedNodes[jEnd] = newCombinedNode(NULL, NULL,
                                                  combinedNodes[jStart], combinedNodes[jStart+1],
                                                  &i, &jStart);
        }else{
            combinedNodes[jEnd] = newCombinedNode(nodes[i], nodes[i+1],
                                                  combinedNodes[jStart], combinedNodes[jStart+1],
                                                  &i, &jStart);
        }
        jEnd++;
    }

    //print the Huffman coding results
    char code[arraySize - 1];
    unsigned long long totalSize = 0;
    printNode(combinedNodes[arraySize - 2], 0, code, &totalSize);
    printf("Total Size: %llu bits\n", totalSize);

    //free everything
    for (i = 0; i < arraySize; i++) free(nodes[i]);
    for (i = 0; i < arraySize - 1; i++) free(combinedNodes[i]);
    return 0;
}
