## Vertical Cross Cubemap to EquiRectangular map


To do a reverse mapping i.e. of a vertical cross cube map to an equirectangular map, we will start with the texture coordinates of a fragment/pixel of the latter.

First, the pair of uv-coordinates is re-mapped from a range of [0.0, 1.0] to the range [-1.0, 1.0].

```metal
  
       uv = 2.0 * uv - 1.0;

```

And further re-mapped into the range [-π, π] for u-coordinate and [-π/2, π/2] for the v-coordinate.

Next a 3D vector is formed with the re-mapped texture coordinates (now labelled as longitude and latitude)

```metal
  
       float3 dir = float3(cos(latitude) * sin(longitude),
                           -sin(latitude),
                           cos(latitude) * cos(longitude));


```

Notice: there is a '-' sign in front of the second parameter. Metal's uv-coordinate has its origin at the top left corner of the 2D NDC space.
Its v-axis is positive vertically downwards.


This 3D vector is then converted to a face index and a pair of texture coordinates by calling the function "directionToCubeFaceUV". It's important to note that the range is [0.0, 1.0] for the returned pair of uv-coordinates.


Since the face index has been determined, the returned pair of uv is further re-mapped into a 3x4 rectangular grid of 12 squares by calling the function  "mapTo3by4Grid". Each of the 12 squares is of dimensions 1:1 i.e. each having an area of 1 unit squared. This function maps the uv into the rectangular grid so that the range will be [0.0, 3.0] and [0.0, 4.0] for the u-coordinate and v-coordinate respectively. However, only 6 of those 12 squares will be used in the mapping so the range is a disjointed set of values.

In order to access the vertical cross texture correctly, we scale the range of the texture coordinates back to [0.0, 1.0]. Only half the pixels of the source texture are accessed.


In order to be able to save the generated 2:1 equirectangular texture, a Metal pipeline must be setup to perform an offscreen render.

 
<br />
<br />
<br />


**Requirements:** XCode 9.x, Swift 4.x and macOS 10.13.4 or later.
<br />
<br />

**Web Links:**


https://en.wikipedia.org/wiki/Cube_mapping
