#!/usr/bin/env python3

import os

from PIL import Image
import torch
from transformers import ViTFeatureExtractor, ViTForImageClassification

extractor = ViTFeatureExtractor.from_pretrained('google/vit-base-patch16-224')
model = ViTForImageClassification.from_pretrained('google/vit-base-patch16-224')


def process_image(im, dbg=False):
    im = Image.open("/tmp/out.png")
    im = im.resize((224, 224))

    if dbg:
        print(f"""
        Run 'telnet localhost 4444' to get the pdb prompt before the failing 
        extractor() call.
        
        Then give pdb the 'n' command to execute the extractor() call which
        will hang.
        """)
        RemotePdb('127.0.0.1', 4444).set_trace()

    pid = os.getpid()
    print(f""" 
    In a different terminal run 'gdb -p {pid} -ex bt --batch' to see a
    backtrace for where pytorch is hung.  
    """)
    
    encoding = extractor(images=im, return_tensors="pt")

    with torch.no_grad():
        outputs = model(encoding['pixel_values'])

    prediction = [
        model.config.id2label[x] for x in
        outputs.logits.topk(3).indices[0].tolist()
    ]

    return prediction


def application(env, start_response):
    start_response('200 OK', [('Content-Type','text/html')])
    return str(process_image("", dbg=False)).encode("utf-8")

if __name__ == "__main__":
    # This passes
    im = "/tmp/out.png"
    print(process_image(im, dbg=False))
else:
    # This fails
    import remote_pdb
    from remote_pdb import RemotePdb

    server = application
