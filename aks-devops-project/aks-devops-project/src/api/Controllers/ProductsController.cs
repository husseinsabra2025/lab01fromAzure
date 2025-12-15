using Microsoft.AspNetCore.Mvc;

namespace api.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ProductsController : ControllerBase
    {
        private readonly ILogger<ProductsController> _logger;
        private static List<Product> _products = new()
        {
            new Product { Id = 1, Name = "Laptop", Price = 999.99m, Category = "Electronics" },
            new Product { Id = 2, Name = "Mouse", Price = 29.99m, Category = "Electronics" },
            new Product { Id = 3, Name = "Keyboard", Price = 79.99m, Category = "Electronics" },
            new Product { Id = 4, Name = "Monitor", Price = 299.99m, Category = "Electronics" },
            new Product { Id = 5, Name = "Headphones", Price = 149.99m, Category = "Audio" }
        };

        public ProductsController(ILogger<ProductsController> logger)
        {
            _logger = logger;
        }

        [HttpGet]
        public IActionResult GetAll()
        {
            _logger.LogInformation("Getting all products. Total count: {Count}", _products.Count);
            return Ok(_products);
        }

        [HttpGet("{id}")]
        public IActionResult GetById(int id)
        {
            var product = _products.FirstOrDefault(p => p.Id == id);
            if (product == null)
            {
                _logger.LogWarning("Product with id {Id} not found", id);
                return NotFound(new { Message = $"Product with id {id} not found" });
            }
            
            _logger.LogInformation("Retrieved product: {ProductName}", product.Name);
            return Ok(product);
        }

        [HttpPost]
        public IActionResult Create([FromBody] Product product)
        {
            product.Id = _products.Max(p => p.Id) + 1;
            _products.Add(product);
            _logger.LogInformation("Created new product: {ProductName} with id {Id}", product.Name, product.Id);
            return CreatedAtAction(nameof(GetById), new { id = product.Id }, product);
        }
    }

    public class Product
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public string Category { get; set; } = string.Empty;
    }
}
