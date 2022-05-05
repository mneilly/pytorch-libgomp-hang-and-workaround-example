# libgomp/PyTorch hang issue

Running PyTorch models using uWSGI can result in the app hanging due
to issues lib libgomp. The issue and possible workarounds are
discussed in this PyTorch issue:

https://github.com/pytorch/pytorch/issues/50669

I spent a couple of days trying to understand why my app was hanging
then timing out and eventually tracked it down to the above known
issue.

Hopefully, this example will be of use to others running into the same
issue.

# Reproducing/Confirming the problem

_classify.py_ uses huggingface transformers with the
google/vit-base-patch16-224 model to perform classification on a
single image.

A _Dockerfile_ is provided with the failing environment.

When _classify.py_ is run from the command line a result is returned and
it exits as expected. When _classify.py_ is run through _uwsgi_ behind
_nginx_ _pytorch_ hangs when _torch.tensor(...)_ is called trying to convert
the image to a tensor. The _gdb_ backtrace shows that _pytorch_ is stuck
somewhere inside _libgomp_.

The image has _remote_pdb_ and _gdb_ installed. 

To build the docker image:

```
DOCKER_BUILDKIT=1 docker build -t classify .
```

To launch the container:
(This assumes that ports 8888, 8443 and 8080 are not being used on your host)

```
docker run --privileged -d -p 8888:80 -p 8443:443 -p 8080:8080 classify
```    

To see that the script passes when not run under _uwsgi_:

```
docker exec -it <container_name> /app/classify/classify.py
```

 Which should output something like the following:
 
>['street sign', 'book jacket, dust cover, dust jacket, dust wrapper', 'traffic light, traffic signal, stoplight']
       
To reproduce the failure:

```
docker exec -it <container_name> tail -f /var/log/uwsgi/uwsgi.log
```

You may need to wait a little bit to be sure _uwsgi_ is running and
try the tail again.

In your browser goto _localhost:8888_. You should see a white page
that is waiting to load.

Run the gdb command shown in the log file above. It should show that
things are stuck in libgomp...

```
docker exec -it <container_name> gdb -p <pid> -ex bt --batch
```

The backtrace should show things are stuck in libgomp similar to the following:

```
(gdb) bt -frame-arguments none 10
#0  0x00007f3d587c8cab in ?? () from /usr/local/lib/python3.9/dist-packages/torch/lib/libgomp-a34b3233.so.1
#1  0x00007f3d587c77e9 in ?? () from /usr/local/lib/python3.9/dist-packages/torch/lib/libgomp-a34b3233.so.1
#2  0x00007f3d414ae471 in at::TensorIteratorBase::for_each(c10::function_ref<void (char**, long const*, long, long)>, long) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#3  0x00007f3d44585bde in at::native::(anonymous namespace)::copy_same_dtype(at::TensorIteratorBase&, bool, bool) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#4  0x00007f3d4458630f in at::native::(anonymous namespace)::copy_kernel(at::TensorIterator&, bool) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#5  0x00007f3d416ce4e3 in at::native::copy_impl(at::Tensor&, at::Tensor const&, bool) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#6  0x00007f3d416cf331 in at::native::copy_(at::Tensor&, at::Tensor const&, bool) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#7  0x00007f3d41f933ad in at::_ops::copy_::call(at::Tensor&, at::Tensor const&, bool) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#8  0x00007f3d41941fd8 in at::native::_to_copy(at::Tensor const&, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, bool, c10::optional<c10::MemoryFormat>) () from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
#9  0x00007f3d421c3d5a in c10::impl::wrap_kernel_functor_unboxed_<c10::impl::detail::WrapFunctionIntoFunctor_<c10::CompileTimeFunctionPointer<at::Tensor (at::Tensor const&, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, bool, c10::optional<c10::MemoryFormat>), &at::(anonymous namespace)::(anonymous namespace)::wrapper___to_copy>, at::Tensor, c10::guts::typelist::typelist<at::Tensor const&, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, bool, c10::optional<c10::MemoryFormat> > >, at::Tensor (at::Tensor const&, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, bool, c10::optional<c10::MemoryFormat>)>::call(c10::OperatorKernel*, c10::DispatchKeySet, at::Tensor const&, c10::optional<c10::ScalarType>, c10::optional<c10::Layout>, c10::optional<c10::Device>, c10::optional<bool>, bool, c10::optional<c10::MemoryFormat>) ()
   from /usr/local/lib/python3.9/dist-packages/torch/lib/libtorch_cpu.so
...
```

# Using remote_pdb

If you want to break in python before the feature extractor call edit
_classify.py_ and modify the call to _process_image()_ in the
_application()_ function to pass dbg=True then after loading the page
in your browser run:

```
docker exec -it <container_name> telnet localhost 4444
```

That will leave you at the pdb prompt just before the failing
extractor call.  The hang occurs inside feature_extractor in the
huggingface model when calling torch.tensor(value) on the image numpy
array.

# The workaround

Edit entrypoint.sh to comment out the uwsgi call after the _# Fails_
line and uncomment the uwsgi call after the _# Workaround_ line.

Then rebuild the container and run it again. Opening localhost:8888
should now return the expected results.

