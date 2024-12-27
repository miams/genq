# Favorite Commands


**Citation Count by Person**
List people by how many citations they have.
`rmgc list all-citations | select RIN Givens Surname | uniq-by -c RIN | flatten | move count --after RIN | sort-by count --reverse`
