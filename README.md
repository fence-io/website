# website

## Useful links

1. Syntax highlighting

    - Chroma Style Gallery: https://xyproto.github.io/splash/docs/all.html
    - Hugo Config: https://gohugo.io/getting-started/configuration-markup/#highlight

## Tips for writing an article

1. Custom image in the list page

    To get your image displayed on the list page, name it `featured.extension` (extension can be svg or any image type).
    
    It will be automatically picked up by the generator and used when rendering the list page.

1. Code fences with console output

    When adding a code snippet with console output, it's usually best to not specify any language to avoid the data being misinterpreted.

    Bad:
    ```bash
    root@ubuntu # ip route
    default via 192.168.64.1 dev enp0s1 proto dhcp src 192.168.64.3 metric 100
    172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
    172.18.0.0/16 dev br-38055463db3c proto kernel scope link src 172.18.0.1
    192.168.64.0/24 dev enp0s1 proto kernel scope link src 192.168.64.3 metric 100
    192.168.64.1 dev enp0s1 proto dhcp scope link src 192.168.64.3 metric 100
    ```

    Good:
    ```
    root@ubuntu # ip route
    default via 192.168.64.1 dev enp0s1 proto dhcp src 192.168.64.3 metric 100
    172.17.0.0/16 dev docker0 proto kernel scope link src 172.17.0.1 linkdown
    172.18.0.0/16 dev br-38055463db3c proto kernel scope link src 172.18.0.1
    192.168.64.0/24 dev enp0s1 proto kernel scope link src 192.168.64.3 metric 100
    192.168.64.1 dev enp0s1 proto dhcp scope link src 192.168.64.3 metric 100
    ```
    
    In the example above `# ip route` is considered a comment when the language is `bash` and this is not correct.

2. Taxonomies

    We support the following taxonomies: `tags`, `categories`, `authors` and `series`.

    You can specify them using front matter like this:

    ```md
    ---
    authors:
    - Sara Qasmi
    categories:
    - Networking
    tags:
    - KinD
    - Cilium
    - Load Balancer
    - MacOS
    series:
    - Networking
    ---
    ```
