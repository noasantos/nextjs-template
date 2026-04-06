function pascalFromSnake(table: string): string {
  return table
    .split("_")
    .map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase())
    .join("")
}

function camelFromSnake(snake: string): string {
  const parts = snake.split("_")
  if (parts.length === 0 || !parts[0]) {
    return snake
  }
  return (
    parts[0].toLowerCase() +
    parts
      .slice(1)
      .map((p) => p.charAt(0).toUpperCase() + p.slice(1).toLowerCase())
      .join("")
  )
}

export { camelFromSnake, pascalFromSnake }
