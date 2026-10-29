// Native export checks decoded bytes; imports and exports share this same ceiling.
export const MAX_TRANSFER_BYTES=20*1024*1024;
export function assertTransferSize(size){
 if(size>MAX_TRANSFER_BYTES)throw Error('File exceeds the 20 MiB limit (20,971,520 bytes). No data was transferred. Reduce the dataset or photos before trying again.');
}
